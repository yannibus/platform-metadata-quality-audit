import { LightningElement, api } from 'lwc';

const ATTRIBUTE_LABEL = { description: 'Description', inlineHelpText: 'Texte d\'aide', label: 'Libellé' };
const STATUS_LABEL = { APPLIED: 'Appliqué', FAILED: 'Échec', SKIPPED: 'Ignoré' };
const STATUS_CLASS = { APPLIED: 'slds-theme_success', FAILED: 'slds-theme_error', SKIPPED: 'slds-theme_warning' };

export default class ApplyReport extends LightningElement {
    @api report;
    @api items = [];

    get viewRows() {
        const byId = new Map((this.items || []).map((i) => [i.id, i]));
        return ((this.report && this.report.results) || []).map((r) => {
            const item = byId.get(r.id) || {};
            let verifiedLabel = '';
            if (r.status === 'APPLIED') { verifiedLabel = r.verified ? 'Vérifié' : 'Non vérifié'; }
            return {
                id: r.id,
                field: item.field || '',
                attributeLabel: ATTRIBUTE_LABEL[item.attribute] || item.attribute || '',
                statusLabel: STATUS_LABEL[r.status] || r.status,
                badgeClass: 'slds-badge ' + (STATUS_CLASS[r.status] || ''),
                verifiedLabel,
                message: r.message || ''
            };
        });
    }
}
