public with sharing class ProposalApplier {
    public static AuditModels.ApplyReport apply(String objectApiName, List<AuditModels.Proposal> items) {
        LanguageGuard.Result g = LanguageGuard.check();
        if (!g.ok) {
            throw new AuraHandledException('Application bloquée : votre langue (' + g.userLanguage + ') diffère de celle de l\'org (' + g.orgLanguage
                + '). Les libellés lus seraient des traductions et les réécrire écraserait les textes de référence. Changez votre langue ou connectez-vous avec un utilisateur dans la langue de l\'org.');
        }
        AuditModels.ObjectSnapshot before = MetadataReader.readObject(objectApiName);
        List<AuditModels.Proposal> valid = ProposalValidator.validate(before, items);
        AuditModels.ApplyReport report = new AuditModels.ApplyReport();
        Set<Integer> validIds = new Set<Integer>();
        for (AuditModels.Proposal p : valid) { validIds.add(p.id); }
        for (AuditModels.Proposal p : items) {
            if (validIds.contains(p.id)) { continue; }
            AuditModels.ApplyResult r = new AuditModels.ApplyResult();
            r.id = p.id; r.status = 'SKIPPED'; r.verified = false; r.message = 'Ligne ignorée (non cochée, vide, hors limites, gérée par un package ou inchangée).';
            report.results.add(r);
        }
        List<AuditModels.ApplyResult> written = valid.isEmpty() ? new List<AuditModels.ApplyResult>() : MetadataApiClient.writeProposals(objectApiName, valid);
        // Pas de relecture ici : dans la même transaction que l'appel externe, describe renvoie des valeurs en cache.
        // Le LWC appelle verifyApplied dans une requête séparée.
        report.results.addAll(written);
        for (AuditModels.ApplyResult r : report.results) {
            if (r.status == 'APPLIED') { report.applied++; } else if (r.status == 'SKIPPED') { report.skipped++; } else { report.failed++; }
        }
        return report;
    }

    // À appeler dans une requête séparée de apply() : relit les valeurs fraîches et marque chaque ligne vérifiée ou non.
    public static List<AuditModels.ApplyResult> verifyApplied(String objectApiName, List<AuditModels.Proposal> items, List<AuditModels.ApplyResult> results) {
        verify(MetadataReader.readObject(objectApiName), items, results);
        return results;
    }

    // Relit les valeurs après écriture et les compare à ce qui a été envoyé.
    @TestVisible static void verify(AuditModels.ObjectSnapshot after, List<AuditModels.Proposal> items, List<AuditModels.ApplyResult> results) {
        Map<String, AuditModels.FieldInfo> byName = new Map<String, AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : after.fields) { byName.put(f.apiName, f); }
        Map<Integer, AuditModels.Proposal> byId = new Map<Integer, AuditModels.Proposal>();
        for (AuditModels.Proposal p : items) { byId.put(p.id, p); }
        for (AuditModels.ApplyResult r : results) {
            if (r.status != 'APPLIED') { continue; }
            AuditModels.Proposal p = byId.get(r.id);
            AuditModels.FieldInfo f = p == null ? null : byName.get(p.field);
            String actual = f == null ? null : p.attribute == 'description' ? f.description : p.attribute == 'inlineHelpText' ? f.helpText : f.label;
            r.verified = (actual != null && actual.equals(p.proposed));
            if (!r.verified) { r.message = 'Écrit mais la relecture donne : ' + (actual == null ? '(vide)' : actual); }
        }
    }
}
