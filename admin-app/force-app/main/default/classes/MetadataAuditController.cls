public with sharing class MetadataAuditController {
    private static final Integer MAX_FIELDS_PER_BATCH = 25;

    @AuraEnabled(cacheable=true)
    public static List<AuditModels.ObjectInfo> listObjects() {
        return MetadataReader.listObjects();
    }

    @AuraEnabled
    public static AuditModels.ObjectSnapshot readObject(String objectApiName) {
        return MetadataReader.readObject(objectApiName);
    }

    // Un lot de champs à la fois : le composant boucle et affiche la progression.
    @AuraEnabled
    public static List<AuditModels.Proposal> analyzeBatch(String objectApiName, List<String> fieldApiNames, Integer sampleSize) {
        if (fieldApiNames == null || fieldApiNames.isEmpty()) { return new List<AuditModels.Proposal>(); }
        if (fieldApiNames.size() > MAX_FIELDS_PER_BATCH) {
            throw new AuraHandledException('Un lot ne peut pas dépasser ' + MAX_FIELDS_PER_BATCH + ' champs.');
        }
        return ProposalGenerator.generate(objectApiName, fieldApiNames, SampleMasker.clamp(sampleSize));
    }

    @AuraEnabled
    // Les entrées arrivent en JSON (String) : la désérialisation Aura d'une liste de classes internes laissait toutes les propriétés à null.
    public static AuditModels.ApplyReport applyProposals(String objectApiName, String itemsJson) {
        return ProposalApplier.apply(objectApiName, parseItems(itemsJson));
    }

    // À appeler dans une requête séparée de applyProposals (voir ProposalApplier.verifyApplied).
    @AuraEnabled
    public static List<AuditModels.ApplyResult> verifyProposals(String objectApiName, String itemsJson, String resultsJson) {
        List<AuditModels.ApplyResult> results = String.isBlank(resultsJson) ? new List<AuditModels.ApplyResult>()
            : (List<AuditModels.ApplyResult>) JSON.deserialize(resultsJson, List<AuditModels.ApplyResult>.class);
        return ProposalApplier.verifyApplied(objectApiName, parseItems(itemsJson), results);
    }

    @TestVisible static List<AuditModels.Proposal> parseItems(String itemsJson) {
        if (String.isBlank(itemsJson)) { return new List<AuditModels.Proposal>(); }
        try {
            return (List<AuditModels.Proposal>) JSON.deserialize(itemsJson, List<AuditModels.Proposal>.class);
        } catch (JSONException e) {
            throw new AuraHandledException('Données invalides : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<SetupChecker.Check> checkSetup() {
        return SetupChecker.run();
    }

    @AuraEnabled
    public static LanguageGuard.Result languageStatus() {
        return LanguageGuard.check();
    }
}
