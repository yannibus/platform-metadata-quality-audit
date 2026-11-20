@IsTest
private class FillRateServiceTest {
    @IsTest static void chunk_batchesAt50Aggregates() {
        List<String> names = new List<String>();
        for (Integer i = 0; i < 120; i++) { names.add('F' + i); }
        List<List<String>> c = FillRateService.chunk(names, 50);
        System.assertEquals(3, c.size());
        System.assertEquals(50, c[0].size());
        System.assertEquals(20, c[2].size());
    }
    @IsTest static void compute_emptyObject_returnsNull() {
        List<AuditModels.FieldInfo> fs = MetadataReader.readObject('Account').fields;
        Map<String, Decimal> r = FillRateService.compute('Account', fs);
        System.assertEquals(null, r.get('Industry'));
    }
    @IsTest static void compute_returnsRatioForFilledField() {
        insert new List<Account>{ new Account(Name = 'A', Industry = 'Banking'), new Account(Name = 'B') };
        List<AuditModels.FieldInfo> fs = MetadataReader.readObject('Account').fields;
        Map<String, Decimal> r = FillRateService.compute('Account', fs);
        System.assertEquals(0.5, r.get('Industry'));
        System.assertEquals(1.0, r.get('Name'));
    }
    @IsTest static void compute_longTextField_returnsNull() {
        insert new Account(Name = 'A', Description = 'long');
        List<AuditModels.FieldInfo> fs = MetadataReader.readObject('Account').fields;
        System.assertEquals(null, FillRateService.compute('Account', fs).get('Description'));
    }

    @IsTest static void compute_isComputedOnTheMostRecentRowsOnly() {
        insert new Account(Name = 'Ancien', Industry = 'Banking');
        insert new List<Account>{ new Account(Name = 'R1'), new Account(Name = 'R2') };
        FillRateService.sampleRows = 2;
        List<AuditModels.FieldInfo> fs = MetadataReader.readObject('Account').fields;
        System.assertEquals(0.0, FillRateService.compute('Account', fs).get('Industry'), 'seuls les 2 enregistrements récents comptent');
    }
}
