import { LightningElement, api } from 'lwc';

export default class SetupWizard extends LightningElement {
    @api checks = [];
    @api loading = false;

    get items() {
        return (this.checks || []).map((c) => ({ ...c, icon: c.ok ? 'utility:success' : 'utility:error' }));
    }

    handleRecheck() {
        this.dispatchEvent(new CustomEvent('recheck'));
    }
}
