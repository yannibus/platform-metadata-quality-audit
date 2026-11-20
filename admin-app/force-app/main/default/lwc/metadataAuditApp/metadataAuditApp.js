import { LightningElement } from 'lwc';
import listObjects from '@salesforce/apex/MetadataAuditController.listObjects';
import readObject from '@salesforce/apex/MetadataAuditController.readObject';
import analyzeBatch from '@salesforce/apex/MetadataAuditController.analyzeBatch';
import applyProposals from '@salesforce/apex/MetadataAuditController.applyProposals';
import verifyProposals from '@salesforce/apex/MetadataAuditController.verifyProposals';
import checkSetup from '@salesforce/apex/MetadataAuditController.checkSetup';
import languageStatus from '@salesforce/apex/MetadataAuditController.languageStatus';

const BATCH_SIZE = 15;
const MAX_FIELDS = 150;
const MAX_LIST = 50;
const APPLY_CHUNK_FIELDS = 10; // limite de temps Apex : une requête = au plus 10 champs écrits
const SYSTEM_FIELDS = new Set(['Id', 'IsDeleted', 'CreatedDate', 'CreatedById', 'LastModifiedDate', 'LastModifiedById',
    'SystemModstamp', 'LastActivityDate', 'LastViewedDate', 'LastReferencedDate']);

const clampSample = (n) => {
    const v = parseInt(n, 10);
    if (Number.isNaN(v)) { return 25; }
    return Math.max(1, Math.min(100, v));
};
const reduceError = (e) => (e && e.body && e.body.message) || (e && e.message) || 'Erreur inattendue';

export default class MetadataAuditApp extends LightningElement {
    objects = [];
    search = '';
    showList = false;
    selected = null;
    sampleSize = 25;
    setupChecks = [];
    setupLoading = false;
    language = { ok: true };
    rows = [];
    warnings = [];
    hiddenFieldCount = 0;
    progress = 0;
    busy = false;
    busyLabel = '';
    error = '';
    analyzed = false;
    report = null;
    appliedItems = [];

    connectedCallback() {
        this.loadStatic();
    }

    async loadStatic() {
        this.setupLoading = true;
        try {
            const [objects, checks, language] = await Promise.all([listObjects(), checkSetup(), languageStatus()]);
            this.objects = objects || [];
            this.setupChecks = checks || [];
            this.language = language || { ok: true };
        } catch (e) {
            this.error = reduceError(e);
        } finally {
            this.setupLoading = false;
        }
    }

    async handleRecheck() {
        this.setupLoading = true;
        try {
            [this.setupChecks, this.language] = await Promise.all([checkSetup(), languageStatus()]);
        } catch (e) {
            this.error = reduceError(e);
        } finally {
            this.setupLoading = false;
        }
    }

    // ---- getters
    get promptOk() { return this.checkOk('promptTemplate'); }
    get allSetupOk() { return this.setupChecks.length > 0 && this.setupChecks.every((c) => c.ok); }
    get showSetup() { return this.setupChecks.length > 0 && !this.allSetupOk; }
    get languageBlocked() { return this.language && this.language.ok === false; }
    get filteredObjects() {
        const q = (this.search || '').toLowerCase();
        return this.objects
            .filter((o) => !q || o.label.toLowerCase().includes(q) || o.apiName.toLowerCase().includes(q))
            .slice(0, MAX_LIST);
    }
    get analyzeDisabled() { return !this.selected || this.busy || !this.promptOk; }
    get hasHiddenFields() { return this.hiddenFieldCount > 0; }
    get showResults() { return this.analyzed && !this.busy; }
    get hasRows() { return this.rows.length > 0; }
    get checkedCount() { return this.rows.filter((r) => r.apply).length; }
    get applyLabel() { return 'Appliquer (' + this.checkedCount + ')'; }
    get applyDisabled() { return this.checkedCount === 0 || this.busy || this.languageBlocked || !this.allSetupOk; }
    get resultsTitle() { return this.rows.length + ' proposition(s) pour ' + (this.selected ? this.selected.label : ''); }

    checkOk(code) {
        const c = this.setupChecks.find((x) => x.code === code);
        return c ? c.ok : false;
    }

    // ---- sélection
    handleSearch(event) {
        this.search = event.target.value;
        this.selected = null;
        this.showList = true;
    }
    handleFocus() { this.showList = true; }
    handlePick(event) {
        const api = event.currentTarget.dataset.api;
        this.selected = this.objects.find((o) => o.apiName === api);
        this.search = this.selected.label + ' (' + this.selected.apiName + ')';
        this.showList = false;
    }
    handleSample(event) {
        this.sampleSize = clampSample(event.target.value);
        event.target.value = this.sampleSize;
    }

    // ---- analyse
    async handleAnalyze() {
        this.busy = true;
        this.busyLabel = 'Lecture des métadonnées…';
        this.error = '';
        this.warnings = [];
        this.rows = [];
        this.report = null;
        this.appliedItems = [];
        this.progress = 0;
        try {
            const objectApiName = this.selected.apiName;
            const snapshot = await readObject({ objectApiName });
            this.hiddenFieldCount = (snapshot.obj && snapshot.obj.hiddenFieldCount) || 0;
            const fieldLabels = {};
            let names = snapshot.fields
                .filter((f) => !f.isManaged && !SYSTEM_FIELDS.has(f.apiName))
                .map((f) => { fieldLabels[f.apiName] = f.label; return f.apiName; });
            if (names.length > MAX_FIELDS) {
                this.warnings = [...this.warnings, 'Objet volumineux : seuls les ' + MAX_FIELDS + ' premiers champs (custom d\'abord) sont analysés.'];
                names = names.slice(0, MAX_FIELDS);
            }
            const batches = [];
            for (let i = 0; i < names.length; i += BATCH_SIZE) { batches.push(names.slice(i, i + BATCH_SIZE)); }
            let all = [];
            for (let i = 0; i < batches.length; i++) {
                this.busyLabel = 'Analyse des champs (' + (i + 1) + '/' + batches.length + ')…';
                try {
                    const res = await analyzeBatch({ objectApiName, fieldApiNames: batches[i], sampleSize: this.sampleSize });
                    all = all.concat(res);
                } catch (e) {
                    this.warnings = [...this.warnings, 'Lot ' + (i + 1) + ' ignoré : ' + reduceError(e)];
                }
                this.progress = Math.round(((i + 1) / batches.length) * 100);
            }
            // Coché d'office : manquant ou faible. Les textes « corrects » restent à l'appréciation de l'admin.
            this.rows = all.map((p, idx) => ({ ...p, id: idx + 1, fieldLabel: fieldLabels[p.field] || p.field, apply: p.status !== 'ADEQUATE' }));
        } catch (e) {
            this.error = reduceError(e);
        } finally {
            this.busy = false;
            this.analyzed = true;
        }
    }

    // ---- revue
    handleRowChange(event) {
        const { id, ...changes } = event.detail;
        this.rows = this.rows.map((r) => (r.id === id ? { ...r, ...changes } : r));
    }
    handleCheckAll() { this.rows = this.rows.map((r) => ({ ...r, apply: true })); }
    handleUncheckAll() { this.rows = this.rows.map((r) => ({ ...r, apply: false })); }

    // ---- application : écriture par paquets de 10 champs (une requête Apex chacun), puis relecture fraîche dans une requête séparée
    async handleApply() {
        const objectApiName = this.selected.apiName;
        const items = this.rows.filter((r) => r.apply).map((r) => ({
            id: r.id, level: r.level, field: r.field, fieldIsCustom: r.fieldIsCustom, attribute: r.attribute,
            current: r.current, proposed: r.proposed, status: r.status, fillRate: r.fillRate, apply: true
        }));
        const fields = [...new Set(items.map((i) => i.field))];
        const chunks = [];
        for (let i = 0; i < fields.length; i += APPLY_CHUNK_FIELDS) {
            const names = new Set(fields.slice(i, i + APPLY_CHUNK_FIELDS));
            chunks.push(items.filter((it) => names.has(it.field)));
        }
        this.busy = true;
        this.error = '';
        this.progress = 0;
        let results = [];
        try {
            for (let i = 0; i < chunks.length; i++) {
                this.busyLabel = 'Application des changements (' + (i + 1) + '/' + chunks.length + ')…';
                try {
                    const part = await applyProposals({ objectApiName, itemsJson: JSON.stringify(chunks[i]) });
                    results = results.concat(part.results);
                } catch (e) {
                    const message = reduceError(e);
                    results = results.concat(chunks[i].map((it) => ({ id: it.id, status: 'FAILED', verified: false, message })));
                }
                this.progress = Math.round(((i + 1) / chunks.length) * 80);
            }
            this.busyLabel = 'Vérification des valeurs écrites…';
            try {
                results = await verifyProposals({ objectApiName, itemsJson: JSON.stringify(items), resultsJson: JSON.stringify(results) });
            } catch (e) {
                this.warnings = [...this.warnings, 'Relecture impossible : ' + reduceError(e) + '. Les écritures ci-dessous ont bien été envoyées mais ne sont pas vérifiées.'];
            }
            this.appliedItems = items;
            this.report = {
                results,
                applied: results.filter((r) => r.status === 'APPLIED').length,
                skipped: results.filter((r) => r.status === 'SKIPPED').length,
                failed: results.filter((r) => r.status === 'FAILED').length
            };
        } finally {
            this.busy = false;
            this.progress = 100;
            // Le rapport est au-dessus de la liste : on y ramène l'admin une fois le rendu fait.
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const el = this.template.querySelector('c-apply-report');
                if (el && this.report && typeof el.scrollIntoView === 'function') { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
            }, 0);
        }
    }
}
