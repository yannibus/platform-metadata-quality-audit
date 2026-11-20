import { LightningElement, api } from 'lwc';

const ATTRIBUTE_LABEL = { description: 'Description', inlineHelpText: 'Texte d\'aide', label: 'Libellé' };
const STATUS_LABEL = { MISSING: 'Manquant', POOR: 'Faible', ADEQUATE: 'Correct' };
const STATUS_CLASS = { MISSING: 'slds-theme_error', POOR: 'slds-theme_warning', ADEQUATE: 'slds-theme_info' };
const ICON = { description: 'utility:description', inlineHelpText: 'utility:info', label: 'utility:edit_form' };
const MAX_LENGTH = { description: 1000, inlineHelpText: 510, label: 40 };

export default class AuditResults extends LightningElement {
    @api rows = [];

    get viewRows() {
        return (this.rows || []).map((r) => ({
            ...r,
            fieldLabel: r.fieldLabel || r.field,
            attributeLabel: ATTRIBUTE_LABEL[r.attribute] || r.attribute,
            statusLabel: STATUS_LABEL[r.status] || r.status,
            badgeClass: 'slds-badge ' + (STATUS_CLASS[r.status] || ''),
            fillRateLabel: r.fillRate === null || r.fillRate === undefined ? 'n/a' : Math.round(r.fillRate * 100) + ' %',
            iconName: ICON[r.attribute] || 'utility:description',
            currentLabel: r.current || '(vide)',
            maxLength: MAX_LENGTH[r.attribute] || 1000
        }));
    }

    // Une carte par champ ; description / aide / libellé en lignes distinctes à l'intérieur (ordre de première apparition).
    get groups() {
        const byField = new Map();
        this.viewRows.forEach((r) => {
            if (!byField.has(r.field)) {
                const known = r.fillRate !== null && r.fillRate !== undefined;
                const pct = known ? Math.round(r.fillRate * 100) : 0;
                byField.set(r.field, {
                    field: r.field,
                    fieldLabel: r.fieldLabel,
                    fillRateLabel: r.fillRateLabel,
                    fillKnown: known,
                    fillBarStyle: 'width: ' + pct + '%',
                    fillClass: 'fill-bar ' + (pct < 20 ? 'fill-low' : pct < 70 ? 'fill-mid' : 'fill-high'),
                    items: []
                });
            }
            byField.get(r.field).items.push(r);
        });
        return [...byField.values()];
    }

    handleCheck(event) {
        this.dispatchEvent(new CustomEvent('rowchange', { detail: { id: Number(event.target.dataset.id), apply: event.target.checked } }));
    }

    handleText(event) {
        this.dispatchEvent(new CustomEvent('rowchange', { detail: { id: Number(event.target.dataset.id), proposed: event.target.value } }));
    }
}
