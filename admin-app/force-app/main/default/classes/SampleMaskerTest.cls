@IsTest
private class SampleMaskerTest {
    private static AuditModels.FieldInfo fld(String name, String type) {
        AuditModels.FieldInfo f = new AuditModels.FieldInfo(); f.apiName = name; f.type = type; return f;
    }
    @IsTest static void mask_emailKeepsTwoCharsThenStars() {
        System.assertEquals('jo***', SampleMasker.mask(fld('Contact_Email__c', 'EMAIL'), 'john@x.com'));
    }
    @IsTest static void mask_nameMatchingSensitivePattern() {
        System.assertEquals('FR***', SampleMasker.mask(fld('Customer_IBAN__c', 'STRING'), 'FR7612345'));
    }
    @IsTest static void mask_truncatesOtherValuesTo60() {
        String out = SampleMasker.mask(fld('Notes__c', 'STRING'), 'x'.repeat(100));
        System.assertEquals(60, out.length());
    }
    @IsTest static void mask_nullStaysNull() {
        System.assertEquals(null, SampleMasker.mask(fld('Notes__c', 'STRING'), null));
    }
    @IsTest static void clamp_boundsSizeTo1And100() {
        System.assertEquals(100, SampleMasker.clamp(500));
        System.assertEquals(1, SampleMasker.clamp(0));
        System.assertEquals(25, SampleMasker.clamp(null));
    }
    @IsTest static void sample_returnsMaskedRows() {
        insert new Account(Name = 'Acme Test', Industry = 'Banking');
        List<AuditModels.FieldInfo> fs = new List<AuditModels.FieldInfo>{ fld('Name', 'STRING'), fld('Industry', 'PICKLIST') };
        List<Map<String, String>> rows = SampleMasker.sample('Account', fs, 5);
        System.assertEquals(1, rows.size());
        System.assertEquals('Acme Test', rows[0].get('Name'));
    }

    @IsTest static void mask_frenchApiNamesAreMasked() {
        for (String n : new List<String>{'Date_de_naissance__c', 'Adresse__c', 'NIR__c', 'Numero_Secu__c', 'Salaire_brut__c', 'Passeport__c', 'Mot_de_passe__c'}) {
            System.assertEquals('ab***', SampleMasker.mask(fld(n, 'STRING'), 'abcdef'), n);
        }
    }
    @IsTest static void mask_sensitiveLabelIsMaskedEvenWithNeutralApiName() {
        AuditModels.FieldInfo f = fld('Champ_42__c', 'STRING');
        f.label = 'Numéro de sécurité sociale';
        System.assertEquals('12***', SampleMasker.mask(f, '123456789'));
    }
    @IsTest static void mask_harmlessNamesAreNotMasked() {
        System.assertEquals('Gold', SampleMasker.mask(fld('Rating', 'STRING'), 'Gold'));
        System.assertEquals('Senior', SampleMasker.mask(fld('Seniority__c', 'STRING'), 'Senior'));
    }

    // L'échantillon doit être les N derniers enregistrements MIS À JOUR (ordre décroissant), jamais les plus anciens.
    @IsTest static void sample_takesTheMostRecentlyUpdatedRecordsFirst() {
        insert new List<Account>{ new Account(Name = 'A'), new Account(Name = 'B'), new Account(Name = 'C') };
        List<AuditModels.FieldInfo> fs = new List<AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : MetadataReader.readObject('Account').fields) { if (f.apiName == 'Name') { fs.add(f); } }
        List<Map<String, String>> rows = SampleMasker.sample('Account', fs, 1);
        System.assertEquals(1, rows.size());
        System.assertEquals('C', rows[0].get('Name'), 'en ascendant on obtiendrait A');
    }

    @IsTest static void recentOrder_isDescendingOnLastModifiedDate() {
        Map<String, Schema.SObjectField> dm = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        System.assertEquals('LastModifiedDate DESC, Id DESC', SampleMasker.recentOrder(dm));
        System.assertEquals('Id DESC', SampleMasker.recentOrder(new Map<String, Schema.SObjectField>()));
    }
}
