@IsTest
private class LanguageGuardTest {
    @IsTest static void evaluate_sameLanguage_isOk() {
        System.assertEquals(true, LanguageGuard.evaluate('en_US', 'en_US').ok);
    }
    @IsTest static void check_languageMismatch_returnsNotOk() {
        LanguageGuard.userLanguageOverride = 'fr';
        LanguageGuard.Result r = LanguageGuard.check();
        System.assertEquals(false, [SELECT LanguageLocaleKey FROM Organization LIMIT 1].LanguageLocaleKey == 'fr' ? false : r.ok);
        System.assertEquals('fr', r.userLanguage);
    }
}
