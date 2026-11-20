import { createElement } from 'lwc';
import SetupWizard from 'c/setupWizard';

describe('c-setup-wizard', () => {
    afterEach(() => { while (document.body.firstChild) { document.body.removeChild(document.body.firstChild); } });

    it('setupWizard shows action for each failing check', async () => {
        const el = createElement('c-setup-wizard', { is: SetupWizard });
        el.checks = [
            { code: 'a', label: 'OK check', ok: true, action: null },
            { code: 'b', label: 'KO check', ok: false, action: 'Faites ceci' },
            { code: 'c', label: 'KO 2', ok: false, action: 'Puis cela' }
        ];
        document.body.appendChild(el);
        await Promise.resolve();
        const actions = el.shadowRoot.querySelectorAll('[data-id="action"]');
        expect(actions).toHaveLength(2);
        expect(actions[0].textContent).toBe('Faites ceci');
    });

    it('fires recheck when the button is clicked', async () => {
        const el = createElement('c-setup-wizard', { is: SetupWizard });
        document.body.appendChild(el);
        const handler = jest.fn();
        el.addEventListener('recheck', handler);
        el.shadowRoot.querySelector('[data-id="recheck"]').click();
        expect(handler).toHaveBeenCalled();
    });
});
