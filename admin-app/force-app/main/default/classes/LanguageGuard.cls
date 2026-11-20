public with sharing class LanguageGuard {
    public class Result {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public String orgLanguage;
        @AuraEnabled public String userLanguage;
    }
    @TestVisible static String userLanguageOverride;

    public static Result evaluate(String orgLanguage, String userLanguage) {
        Result r = new Result();
        r.orgLanguage = orgLanguage; r.userLanguage = userLanguage; r.ok = (orgLanguage == userLanguage);
        return r;
    }
    // La langue de l'utilisateur doit être celle de l'org : sinon describe renvoie des libellés traduits
    // et les réécrire écraserait le texte de référence.
    public static Result check() {
        String org = [SELECT LanguageLocaleKey FROM Organization LIMIT 1].LanguageLocaleKey;
        String user = userLanguageOverride != null ? userLanguageOverride : UserInfo.getLanguage();
        return evaluate(org, user);
    }
}
