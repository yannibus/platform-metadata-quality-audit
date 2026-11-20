@IsTest
private class ProposalValidatorTest {
    private static AuditModels.ObjectSnapshot snap() {
        AuditModels.ObjectSnapshot s = new AuditModels.ObjectSnapshot();
        s.obj = new AuditModels.ObjectInfo(); s.obj.apiName = 'Account';
        s.fields = new List<AuditModels.FieldInfo>{ f('Industry', false, false), f('Cust__c', true, false), f('ns__M__c', true, true) };
        return s;
    }
    private static AuditModels.FieldInfo f(String n, Boolean c, Boolean m) {
        AuditModels.FieldInfo x = new AuditModels.FieldInfo(); x.apiName = n; x.isCustom = c; x.isManaged = m; x.label = n; return x;
    }
    private static AuditModels.Proposal p(String field, String attr, String text, Boolean apply) {
        AuditModels.Proposal x = new AuditModels.Proposal(); x.id = 1; x.level = 'field'; x.field = field; x.attribute = attr; x.proposed = text; x.apply = apply; return x;
    }
    @IsTest static void validate_keepsValidCheckedItem() {
        System.assertEquals(1, ProposalValidator.validate(snap(), new List<AuditModels.Proposal>{ p('Industry', 'description', 'Secteur du compte', true) }).size());
    }
    @IsTest static void validate_dropsUncheckedEmptyManagedAndUnknown() {
        List<AuditModels.Proposal> input = new List<AuditModels.Proposal>{
            p('Industry', 'description', 'ok', false), p('Industry', 'description', '  ', true),
            p('ns__M__c', 'description', 'x', true), p('Nope__c', 'description', 'x', true) };
        System.assertEquals(0, ProposalValidator.validate(snap(), input).size());
    }
    @IsTest static void validate_dropsOverLimitAndLabelOnStandard() {
        List<AuditModels.Proposal> input = new List<AuditModels.Proposal>{
            p('Cust__c', 'description', 'x'.repeat(1001), true), p('Cust__c', 'inlineHelpText', 'x'.repeat(511), true),
            p('Cust__c', 'label', 'x'.repeat(41), true), p('Industry', 'label', 'Secteur', true) };
        System.assertEquals(0, ProposalValidator.validate(snap(), input).size());
    }

    @IsTest static void validate_keepsCaseOnlyChange() {
        AuditModels.ObjectSnapshot s = snap();
        s.fields[1].label = 'Customer id';
        System.assertEquals(1, ProposalValidator.validate(s, new List<AuditModels.Proposal>{ p('Cust__c', 'label', 'Customer ID', true) }).size());
    }
}
