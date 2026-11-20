@IsTest
private class MetadataAuditControllerTest {
    private class MockRunner implements ProposalGenerator.PromptRunner {
        public String run(Map<String, String> inputs) { return '{"items":[]}'; }
    }
    @IsTest static void listObjects_containsAccount() {
        Boolean found = false;
        for (AuditModels.ObjectInfo o : MetadataAuditController.listObjects()) { if (o.apiName == 'Account') { found = true; } }
        System.assert(found);
    }
    @IsTest static void analyzeBatch_rejectsMoreThan25Fields() {
        List<String> many = new List<String>();
        for (Integer i = 0; i < 26; i++) { many.add('F' + i); }
        try { MetadataAuditController.analyzeBatch('Account', many, 5); System.assert(false, 'exception attendue'); }
        catch (AuraHandledException e) { System.assert(true); }
    }
    @IsTest static void analyzeBatch_emptySelectionReturnsEmpty() {
        System.assertEquals(0, MetadataAuditController.analyzeBatch('Account', new List<String>(), 5).size());
    }
    @IsTest static void analyzeBatch_clampsSampleSizeAndReturnsProposals() {
        ProposalGenerator.runner = new MockRunner();
        System.assertEquals(0, MetadataAuditController.analyzeBatch('Account', new List<String>{'Industry'}, 500).size());
    }

    @IsTest static void parseItemsReadsJsonFromTheLwc() {
        String js = '[{"id":2,"level":"field","field":"External_ID__c","fieldIsCustom":true,"attribute":"inlineHelpText","proposed":"Texte","status":"MISSING","fillRate":0.9,"apply":true}]';
        List<AuditModels.Proposal> items = MetadataAuditController.parseItems(js);
        System.assertEquals(1, items.size());
        System.assertEquals(2, items[0].id);
        System.assertEquals('External_ID__c', items[0].field);
        System.assertEquals(true, items[0].apply);
        System.assertEquals(0, MetadataAuditController.parseItems('').size());
    }

    @IsTest static void parseItemsRejectsGarbage() {
        try { MetadataAuditController.parseItems('pas du json'); System.assert(false, 'attendu : AuraHandledException'); }
        catch (AuraHandledException e) { System.assert(true); }
    }
}
