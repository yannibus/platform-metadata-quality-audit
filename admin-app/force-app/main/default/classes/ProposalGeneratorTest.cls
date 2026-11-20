@IsTest
private class ProposalGeneratorTest {
    private class MockRunner implements ProposalGenerator.PromptRunner {
        String answer;
        MockRunner(String answer) { this.answer = answer; }
        public String run(Map<String, String> inputs) { return answer; }
    }
    private static AuditModels.FieldInfo fld(String name, Boolean custom, Boolean managed) {
        AuditModels.FieldInfo f = new AuditModels.FieldInfo();
        f.apiName = name; f.label = name; f.type = 'STRING'; f.isCustom = custom; f.isManaged = managed;
        return f;
    }
    private static String item(String field, String attr, String proposed, String status) {
        return '{"field":"' + field + '","attribute":"' + attr + '","proposed":"' + proposed + '","status":"' + status + '"}';
    }
    private static Map<String, AuditModels.FieldInfo> byName(List<AuditModels.FieldInfo> l) {
        Map<String, AuditModels.FieldInfo> m = new Map<String, AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : l) { m.put(f.apiName, f); }
        return m;
    }

    @IsTest static void generate_parsesModelJson() {
        ProposalGenerator.runner = new MockRunner('```json\n{"items":[' + item('Industry', 'description', 'Secteur d activite principal du compte, utilise pour la segmentation.', 'MISSING') + ']}\n```');
        List<AuditModels.Proposal> out = ProposalGenerator.generate('Account', new List<String>{'Industry', 'Name'}, 5);
        System.assertEquals(1, out.size());
        System.assertEquals('Industry', out[0].field);
        System.assertEquals('description', out[0].attribute);
        System.assertEquals('field', out[0].level);
        System.assertEquals(true, out[0].apply);
        System.assertEquals('MISSING', out[0].status);
    }
    @IsTest static void parse_dropsProposalsOnManagedFields() {
        AuditModels.FieldInfo m = fld('ns__X__c', true, true);
        List<AuditModels.Proposal> out = ProposalGenerator.parse('{"items":[' + item('ns__X__c', 'description', 'Texte propose assez long pour passer.', 'MISSING') + ']}', byName(new List<AuditModels.FieldInfo>{m}), new Map<String, Decimal>());
        System.assertEquals(0, out.size());
    }
    @IsTest static void parse_neverProposesLabelOnStandardField() {
        AuditModels.FieldInfo s = fld('Industry', false, false);
        List<AuditModels.Proposal> out = ProposalGenerator.parse('{"items":[' + item('Industry', 'label', 'Secteur', 'POOR') + ']}', byName(new List<AuditModels.FieldInfo>{s}), new Map<String, Decimal>());
        System.assertEquals(0, out.size());
    }
    @IsTest static void parse_keepsLabelOnCustomField() {
        AuditModels.FieldInfo c = fld('Cust_Ref__c', true, false);
        List<AuditModels.Proposal> out = ProposalGenerator.parse('{"items":[' + item('Cust_Ref__c', 'label', 'Référence client', 'POOR') + ']}', byName(new List<AuditModels.FieldInfo>{c}), new Map<String, Decimal>());
        System.assertEquals(1, out.size());
    }
    @IsTest static void parse_dropsGoodAndUnknownFieldsAndEmptyText() {
        AuditModels.FieldInfo c = fld('A__c', true, false);
        String j = '{"items":[' + item('A__c', 'description', 'ok', 'GOOD') + ',' + item('Z__c', 'description', 'texte', 'MISSING') + ',' + item('A__c', 'inlineHelpText', '', 'MISSING') + ']}';
        System.assertEquals(0, ProposalGenerator.parse(j, byName(new List<AuditModels.FieldInfo>{c}), new Map<String, Decimal>()).size());
    }
    @IsTest static void parse_truncatesDescriptionOver1000Chars() {
        AuditModels.FieldInfo c = fld('A__c', true, false);
        List<AuditModels.Proposal> out = ProposalGenerator.parse('{"items":[' + item('A__c', 'description', 'x'.repeat(1500), 'MISSING') + ']}', byName(new List<AuditModels.FieldInfo>{c}), new Map<String, Decimal>());
        System.assertEquals(1000, out[0].proposed.length());
    }
    @IsTest static void parse_dropsLabelOver40Chars() {
        AuditModels.FieldInfo c = fld('A__c', true, false);
        System.assertEquals(0, ProposalGenerator.parse('{"items":[' + item('A__c', 'label', 'x'.repeat(41), 'POOR') + ']}', byName(new List<AuditModels.FieldInfo>{c}), new Map<String, Decimal>()).size());
    }
    @IsTest static void generate_invalidJson_throwsForThisBatchOnly() {
        ProposalGenerator.runner = new MockRunner('désolé, pas de JSON ici');
        try { ProposalGenerator.generate('Account', new List<String>{'Industry'}, 5); System.assert(false, 'exception attendue'); }
        catch (AuraHandledException e) { System.assert(true); }
    }

    @IsTest static void parse_keepsCaseOnlyChange() {
        AuditModels.FieldInfo c = fld('A__c', true, false);
        c.label = 'Customer id';
        List<AuditModels.Proposal> out = ProposalGenerator.parse('{"items":[' + item('A__c', 'label', 'Customer ID', 'POOR') + ']}', byName(new List<AuditModels.FieldInfo>{c}), new Map<String, Decimal>());
        System.assertEquals(1, out.size());
    }

    private static AuditModels.FieldInfo lbl(String api, String label, Boolean custom) {
        AuditModels.FieldInfo f = fld(api, custom, false); f.label = label; return f;
    }
    @IsTest static void findSimilar_pairsStandardAndCustomWithSameLabel() {
        List<AuditModels.FieldInfo> all = new List<AuditModels.FieldInfo>{ lbl('Industry', 'Industry', false), lbl('Industry__c', 'Industry', true), lbl('Rating', 'Rating', false) };
        Map<String, List<AuditModels.FieldInfo>> m = ProposalGenerator.findSimilar(all);
        System.assertEquals('Industry__c', m.get('Industry')[0].apiName);
        System.assertEquals('Industry', m.get('Industry__c')[0].apiName);
        System.assertEquals(null, m.get('Rating'));
    }
    @IsTest static void findSimilar_pairsOnApiNameBaseEvenWithDifferentLabels() {
        List<AuditModels.FieldInfo> all = new List<AuditModels.FieldInfo>{ lbl('Region', 'Region', false), lbl('Region__c', 'Zone commerciale', true) };
        System.assertEquals(1, ProposalGenerator.findSimilar(all).get('Region').size());
    }
    @IsTest static void findSimilar_ignoresUnrelatedFields() {
        List<AuditModels.FieldInfo> all = new List<AuditModels.FieldInfo>{ lbl('Industry', 'Industry', false), lbl('Segment__c', 'Segment', true) };
        System.assertEquals(0, ProposalGenerator.findSimilar(all).size());
    }
    @IsTest static void payload_includesSimilarFieldsOfEachSelectedField() {
        AuditModels.FieldInfo std = lbl('Industry', 'Industry', false);
        AuditModels.FieldInfo cust = lbl('Industry__c', 'Industry', true); cust.description = 'Secteur interne';
        List<Map<String, Object>> out = ProposalGenerator.payload(new List<AuditModels.FieldInfo>{ std }, new List<AuditModels.FieldInfo>{ std, cust }, new Map<String, Decimal>{ 'Industry' => 0.8 });
        String j = JSON.serialize(out);
        System.assert(j.contains('similarFields'), j);
        System.assert(j.contains('Industry__c') && j.contains('Secteur interne'), j);
    }
}
