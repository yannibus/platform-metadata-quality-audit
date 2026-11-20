public with sharing class SetupChecker {
    public class Check {
        @AuraEnabled public String code;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean ok;
        @AuraEnabled public String action;
    }
    @TestVisible static Boolean namedCredentialExistsOverride;

    public static List<Check> run() {
        List<Check> out = new List<Check>();
        Boolean ncExists = namedCredentialExistsOverride != null ? namedCredentialExistsOverride
            : ![SELECT Id FROM NamedCredential WHERE DeveloperName = 'Metadata_API_Self' LIMIT 1].isEmpty();
        out.add(check('namedCredential', 'Named Credential « Metadata API Self »', ncExists,
            'Déployez la Named Credential Metadata_API_Self et l\'External Credential associée, avec l\'URL de votre My Domain.'));

        String ping = ncExists ? MetadataApiClient.ping() : 'Named Credential absente';
        out.add(check('metadataApi', 'Accès à la Metadata API (authentification de votre utilisateur)', ping == null,
            ncExists ? 'Authentifiez-vous : avatar → Paramètres → Authentication Settings for External Systems → Metadata Audit Self → Authentifier. Détail : ' + ping
                     : 'Créez d\'abord la Named Credential.'));

        String tpl = ProposalGenerator.checkTemplate();
        out.add(check('promptTemplate', 'Prompt Template « Metadata Quality Proposals »', tpl == null,
            'Activez Einstein Generative AI et vérifiez que le Prompt Template Metadata_Quality_Proposals est actif. Détail : ' + tpl));

        LanguageGuard.Result lang = LanguageGuard.check();
        out.add(check('language', 'Langue de l\'utilisateur = langue de l\'org', lang.ok,
            'Passez votre langue à ' + lang.orgLanguage + ' (actuellement ' + lang.userLanguage + ') pour pouvoir appliquer des changements.'));
        return out;
    }

    private static Check check(String code, String label, Boolean ok, String action) {
        Check c = new Check();
        c.code = code; c.label = label; c.ok = ok; c.action = ok ? null : action;
        return c;
    }
}
