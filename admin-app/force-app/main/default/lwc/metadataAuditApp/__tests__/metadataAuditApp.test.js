import { createElement } from 'lwc';
import MetadataAuditApp from 'c/metadataAuditApp';
import listObjects from '@salesforce/apex/MetadataAuditController.listObjects';
import readObject from '@salesforce/apex/MetadataAuditController.readObject';
import analyzeBatch from '@salesforce/apex/MetadataAuditController.analyzeBatch';
import applyProposals from '@salesforce/apex/MetadataAuditController.applyProposals';
import verifyProposals from '@salesforce/apex/MetadataAuditController.verifyProposals';
import checkSetup from '@salesforce/apex/MetadataAuditController.checkSetup';
import languageStatus from '@salesforce/apex/MetadataAuditController.languageStatus';

jest.mock('@salesforce/apex/MetadataAuditController.listObjects', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MetadataAuditController.readObject', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MetadataAuditController.analyzeBatch', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MetadataAuditController.applyProposals', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MetadataAuditController.verifyProposals', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MetadataAuditController.checkSetup', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MetadataAuditController.languageStatus', () => ({ default: jest.fn() }), { virtual: true });

const flush = async () => { for (let i = 0; i < 6; i++) { await new Promise((r) => setTimeout(r, 0)); } };
const allOk = [
    { code: 'namedCredential', label: 'NC', ok: true }, { code: 'metadataApi', label: 'API', ok: true },
    { code: 'promptTemplate', label: 'PT', ok: true }, { code: 'language', label: 'L', ok: true }
];
const proposals = [
    { id: 1, level: 'field', field: 'Industry', attribute: 'description', status: 'MISSING', proposed: 'Secteur du compte', fillRate: 0.8, apply: true },
    { id: 2, level: 'field', field: 'Rating', attribute: 'inlineHelpText', status: 'POOR', proposed: 'Choisir la note', fillRate: 0.1, apply: true }
];
const snapshot = (hidden = 0) => ({ obj: { apiName: 'Account', label: 'Account', hiddenFieldCount: hidden },
    fields: [{ apiName: 'Industry', label: 'Industry', isManaged: false }, { apiName: 'Rating', label: 'Rating', isManaged: false }] });

async function mount() {
    const el = createElement('c-metadata-audit-app', { is: MetadataAuditApp });
    document.body.appendChild(el);
    await flush();
    return el;
}
const q = (el, id) => el.shadowRoot.querySelector('[data-id="' + id + '"]');
async function pickAccount(el) {
    const search = q(el, 'object-search');
    search.dispatchEvent(new CustomEvent('focus'));
    await flush();
    el.shadowRoot.querySelector('li[data-api="Account"]').click();
    await flush();
}
async function analyze(el) {
    await pickAccount(el);
    q(el, 'analyze').click();
    await flush();
}

describe('c-metadata-audit-app', () => {
    beforeEach(() => {
        listObjects.mockResolvedValue([{ apiName: 'Account', label: 'Account' }, { apiName: 'Contact', label: 'Contact' }]);
        checkSetup.mockResolvedValue(allOk);
        languageStatus.mockResolvedValue({ ok: true, orgLanguage: 'en_US', userLanguage: 'en_US' });
        readObject.mockResolvedValue(snapshot());
        analyzeBatch.mockResolvedValue(proposals.map((p) => ({ ...p })));
        applyProposals.mockResolvedValue({ applied: 2, skipped: 0, failed: 0, results: [{ id: 1, status: 'APPLIED', verified: false }, { id: 2, status: 'APPLIED', verified: false }] });
        verifyProposals.mockImplementation(({ resultsJson }) => Promise.resolve(JSON.parse(resultsJson).map((r) => ({ ...r, verified: true }))));
    });
    afterEach(() => { while (document.body.firstChild) { document.body.removeChild(document.body.firstChild); } jest.clearAllMocks(); });

    it('sampleSize clamps to 1..100', async () => {
        const el = await mount();
        const input = q(el, 'sample-size');
        input.value = 500;
        input.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(input.value).toBe(100);
        input.value = 0;
        input.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(input.value).toBe(1);
    });

    it('analyze button disabled until object selected', async () => {
        const el = await mount();
        expect(q(el, 'analyze').disabled).toBe(true);
        await pickAccount(el);
        expect(q(el, 'analyze').disabled).toBe(false);
    });

    it('apply button shows count of checked rows', async () => {
        const el = await mount();
        await analyze(el);
        expect(q(el, 'apply').label).toBe('Appliquer (2)');
        q(el, 'uncheck-all').click();
        await flush();
        expect(q(el, 'apply').label).toBe('Appliquer (0)');
        expect(q(el, 'apply').disabled).toBe(true);
    });

    it('apply disabled with message when language mismatch', async () => {
        languageStatus.mockResolvedValue({ ok: false, orgLanguage: 'en_US', userLanguage: 'fr' });
        const el = await mount();
        await analyze(el);
        expect(q(el, 'language-warning')).not.toBeNull();
        expect(q(el, 'apply').disabled).toBe(true);
    });

    it('edited proposal text is sent on apply', async () => {
        const el = await mount();
        await analyze(el);
        el.shadowRoot.querySelector('c-audit-results').dispatchEvent(new CustomEvent('rowchange', { detail: { id: 1, proposed: 'Texte corrigé' } }));
        await flush();
        q(el, 'apply').click();
        await flush();
        const sent = applyProposals.mock.calls[0][0];
        expect(JSON.parse(sent.itemsJson).find((i) => i.id === 1).proposed).toBe('Texte corrigé');
        expect(verifyProposals).toHaveBeenCalledTimes(1);
    });

    it('hidden-fields warning shown when hiddenFieldCount > 0', async () => {
        readObject.mockResolvedValue(snapshot(3));
        const el = await mount();
        await analyze(el);
        expect(q(el, 'hidden-fields')).not.toBeNull();
        expect(q(el, 'hidden-fields').textContent).toContain('3 champ');
    });

    it('one failing batch is reported without blocking the others', async () => {
        analyzeBatch.mockRejectedValueOnce({ body: { message: 'Réponse du modèle invalide' } });
        readObject.mockResolvedValue({ obj: { apiName: 'Account', label: 'Account', hiddenFieldCount: 0 },
            fields: Array.from({ length: 20 }, (_, i) => ({ apiName: 'F' + i + '__c', label: 'F' + i, isManaged: false })) });
        const el = await mount();
        await analyze(el);
        expect(analyzeBatch).toHaveBeenCalledTimes(2);
        expect(el.shadowRoot.textContent).toContain('Lot 1 ignoré');
    });

    it('adequate proposals are unchecked by default', async () => {
        analyzeBatch.mockResolvedValue([
            { ...proposals[0] }, { ...proposals[1], status: 'ADEQUATE' }
        ]);
        const el = await mount();
        await analyze(el);
        expect(q(el, 'apply').label).toBe('Appliquer (1)');
    });

    const manyProposals = (n) => Array.from({ length: n }, (_, i) => ({ id: i + 1, level: 'field', field: 'F' + i + '__c', attribute: 'description', status: 'MISSING', proposed: 'Texte ' + i, apply: true }));
    const echoApply = ({ itemsJson }) => { const items = JSON.parse(itemsJson); return Promise.resolve({ applied: items.length, skipped: 0, failed: 0, results: items.map((i) => ({ id: i.id, status: 'APPLIED', verified: false })) }); };

    it('apply is split in chunks of 10 fields', async () => {
        analyzeBatch.mockResolvedValue(manyProposals(25));
        applyProposals.mockImplementation(echoApply);
        const el = await mount();
        await analyze(el);
        q(el, 'apply').click();
        await flush();
        const sizes = applyProposals.mock.calls.map((c) => new Set(JSON.parse(c[0].itemsJson).map((i) => i.field)).size);
        expect(sizes).toEqual([10, 10, 5]);
        expect(verifyProposals).toHaveBeenCalledTimes(1);
    });

    it('a failing chunk is reported as failed and the others still apply', async () => {
        analyzeBatch.mockResolvedValue(manyProposals(25));
        applyProposals.mockImplementationOnce(() => Promise.reject({ body: { message: 'time allotted' } })).mockImplementation(echoApply);
        const el = await mount();
        await analyze(el);
        q(el, 'apply').click();
        await flush();
        const report = el.shadowRoot.querySelector('c-apply-report').report;
        expect(report.failed).toBe(10);
        expect(report.applied).toBe(15);
    });

    it('report is kept when verification fails', async () => {
        verifyProposals.mockRejectedValue({ body: { message: 'boom' } });
        const el = await mount();
        await analyze(el);
        q(el, 'apply').click();
        await flush();
        expect(el.shadowRoot.querySelector('c-apply-report').report).not.toBeNull();
        expect(el.shadowRoot.textContent).toContain('Relecture impossible');
    });
});
