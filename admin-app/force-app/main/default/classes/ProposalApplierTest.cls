@IsTest
private class ProposalApplierTest {
    private static AuditModels.ObjectSnapshot snap(String d) {
        AuditModels.ObjectSnapshot s = new AuditModels.ObjectSnapshot();
        s.obj = new AuditModels.ObjectInfo();
        AuditModels.FieldInfo f = new AuditModels.FieldInfo(); f.apiName = 'Industry'; f.description = d; f.isCustom = false;
        s.fields = new List<AuditModels.FieldInfo>{ f };
        return s;
    }
    private static AuditModels.Proposal prop() {
        AuditModels.Proposal x = new AuditModels.Proposal(); x.id = 1; x.field = 'Industry'; x.attribute = 'description'; x.proposed = 'Secteur'; x.apply = true; return x;
    }
    private static AuditModels.ApplyResult res() { AuditModels.ApplyResult r = new AuditModels.ApplyResult(); r.id = 1; r.status = 'APPLIED'; return r; }
    @IsTest static void apply_languageMismatch_throws() {
        LanguageGuard.userLanguageOverride = 'zz';
        try { ProposalApplier.apply('Account', new List<AuditModels.Proposal>{ prop() }); System.assert(false, 'exception attendue'); }
        catch (AuraHandledException e) { System.assert(true); }
    }
    @IsTest static void verify_marksMatchAsVerified() {
        List<AuditModels.ApplyResult> rs = new List<AuditModels.ApplyResult>{ res() };
        ProposalApplier.verify(snap('Secteur'), new List<AuditModels.Proposal>{ prop() }, rs);
        System.assertEquals(true, rs[0].verified);
    }
    @IsTest static void verify_marksMismatchAsNotVerified() {
        List<AuditModels.ApplyResult> rs = new List<AuditModels.ApplyResult>{ res() };
        ProposalApplier.verify(snap('autre chose'), new List<AuditModels.Proposal>{ prop() }, rs);
        System.assertEquals(false, rs[0].verified);
        System.assert(rs[0].message != null);
    }

    @IsTest static void verify_isCaseSensitive() {
        List<AuditModels.ApplyResult> rs = new List<AuditModels.ApplyResult>{ res() };
        ProposalApplier.verify(snap('secteur'), new List<AuditModels.Proposal>{ prop() }, rs);
        System.assertEquals(false, rs[0].verified, 'Secteur != secteur');
    }
}
