@IsTest
private class MetadataReaderTest {
    @IsTest static void readObject_returnsDescriptionFromFieldDefinition() {
        FieldDefinition fd = [SELECT Description FROM FieldDefinition
            WHERE EntityDefinition.QualifiedApiName = 'Account' AND QualifiedApiName = 'Industry' LIMIT 1];
        AuditModels.ObjectSnapshot s = MetadataReader.readObject('Account');
        AuditModels.FieldInfo industry;
        for (AuditModels.FieldInfo f : s.fields) { if (f.apiName == 'Industry') { industry = f; } }
        System.assertNotEquals(null, industry, 'Industry doit être lu');
        System.assertEquals(fd.Description, industry.description);
        System.assertEquals('Account', s.obj.apiName);
        System.assertEquals(false, s.obj.isCustom);
    }
    @IsTest static void isManaged_flagsNamespacedNames() {
        System.assertEquals(true, MetadataReader.isManaged('ns__Field__c'));
        System.assertEquals(false, MetadataReader.isManaged('Field__c'));
        System.assertEquals(false, MetadataReader.isManaged('Industry'));
    }
    @IsTest static void sortFields_putsCustomFirst() {
        AuditModels.FieldInfo a = new AuditModels.FieldInfo(); a.apiName = 'Name'; a.isCustom = false;
        AuditModels.FieldInfo b = new AuditModels.FieldInfo(); b.apiName = 'X__c'; b.isCustom = true;
        List<AuditModels.FieldInfo> out = MetadataReader.sortFields(new List<AuditModels.FieldInfo>{a, b});
        System.assertEquals('X__c', out[0].apiName);
    }
    @IsTest static void readObject_unknownObject_throwsAuraHandledException() {
        try { MetadataReader.readObject('Nope__c'); System.assert(false, 'exception attendue'); }
        catch (AuraHandledException e) { System.assert(true); }
    }
    @IsTest static void listObjects_containsAccountSortedByLabel() {
        List<AuditModels.ObjectInfo> l = MetadataReader.listObjects();
        Boolean found = false;
        for (AuditModels.ObjectInfo o : l) { if (o.apiName == 'Account') { found = true; } }
        System.assert(found);
        System.assert(l[0].label.toLowerCase() <= l[l.size() - 1].label.toLowerCase());
    }
    @IsTest static void isTechnical_excludesShareHistoryAndDataCloudObjects() {
        System.assertEquals(true, MetadataReader.isTechnical('Foo__Share'));
        System.assertEquals(true, MetadataReader.isTechnical('Bar__dlm'));
        System.assertEquals(false, MetadataReader.isTechnical('Account'));
        System.assertEquals(false, MetadataReader.isTechnical('Project__c'));
    }
}
