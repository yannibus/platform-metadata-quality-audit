public with sharing class ProposalValidator {
    private static final Map<String, Integer> LIMITS = new Map<String, Integer>{'description' => 1000, 'inlineHelpText' => 510, 'label' => 40};

    public static List<AuditModels.Proposal> validate(AuditModels.ObjectSnapshot snap, List<AuditModels.Proposal> items) {
        Map<String, AuditModels.FieldInfo> byName = new Map<String, AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : snap.fields) { byName.put(f.apiName, f); }
        List<AuditModels.Proposal> kept = new List<AuditModels.Proposal>();
        for (AuditModels.Proposal p : items) {
            AuditModels.FieldInfo f = byName.get(p.field);
            if (p.apply != true || f == null || f.isManaged == true || p.level != 'field' && p.level != null) { continue; }
            if (String.isBlank(p.proposed) || !LIMITS.containsKey(p.attribute)) { continue; }
            if (p.attribute == 'label' && f.isCustom != true) { continue; }
            if (p.proposed.length() > LIMITS.get(p.attribute)) { continue; }
            String current = p.attribute == 'description' ? f.description : p.attribute == 'inlineHelpText' ? f.helpText : f.label;
            if (current != null && current.equals(p.proposed)) { continue; }
            p.fieldIsCustom = f.isCustom;
            kept.add(p);
        }
        return kept;
    }
}
