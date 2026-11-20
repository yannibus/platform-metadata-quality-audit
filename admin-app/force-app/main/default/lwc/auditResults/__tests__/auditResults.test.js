import { createElement } from 'lwc';
import AuditResults from 'c/auditResults';

const rows = [
    { id: 1, field: 'A__c', fieldLabel: 'Champ A', attribute: 'description', status: 'MISSING', fillRate: 0.5, current: null, proposed: 'd', apply: true },
    { id: 2, field: 'B__c', fieldLabel: 'Champ B', attribute: 'description', status: 'POOR', fillRate: null, current: 'x', proposed: 'd2', apply: false },
    { id: 3, field: 'A__c', fieldLabel: 'Champ A', attribute: 'inlineHelpText', status: 'MISSING', fillRate: 0.5, current: null, proposed: 'h', apply: true }
];
const flush = () => Promise.resolve();

describe('c-audit-results', () => {
    afterEach(() => { while (document.body.firstChild) { document.body.removeChild(document.body.firstChild); } });

    it('groups description and help text under their field', async () => {
        const el = createElement('c-audit-results', { is: AuditResults });
        el.rows = rows;
        document.body.appendChild(el);
        await flush();
        const groups = el.shadowRoot.querySelectorAll('[data-id="group"]');
        expect(groups).toHaveLength(2);
        expect(groups[0].querySelectorAll('[data-id="row"]')).toHaveLength(2);
        expect(groups[0].textContent).toContain('Description');
        expect(groups[0].textContent).toContain('Texte d\'aide');
        expect(groups[1].querySelectorAll('[data-id="row"]')).toHaveLength(1);
    });

    it('emits rowchange with the row id when a checkbox changes', async () => {
        const el = createElement('c-audit-results', { is: AuditResults });
        el.rows = rows;
        document.body.appendChild(el);
        await flush();
        const handler = jest.fn();
        el.addEventListener('rowchange', handler);
        const box = el.shadowRoot.querySelector('lightning-input[data-id="3"]');
        box.checked = false;
        box.dispatchEvent(new CustomEvent('change'));
        expect(handler.mock.calls[0][0].detail).toEqual({ id: 3, apply: false });
    });
});
