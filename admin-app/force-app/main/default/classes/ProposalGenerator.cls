public with sharing class ProposalGenerator {
    public interface PromptRunner { String run(Map<String, String> inputs); }

    private static final String TEMPLATE = 'Metadata_Quality_Proposals';
    private static final Set<String> ATTRIBUTES = new Set<String>{'description', 'inlineHelpText', 'label'};
    private static final Set<String> STATUSES = new Set<String>{'MISSING', 'POOR', 'ADEQUATE'};
    private static final Map<String, Integer> LIMITS = new Map<String, Integer>{'description' => 1000, 'inlineHelpText' => 510, 'label' => 40};

    @TestVisible static PromptRunner runner = new EinsteinRunner();

    public class EinsteinRunner implements PromptRunner {
        public String run(Map<String, String> inputs) {
            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.inputParams = new Map<String, ConnectApi.WrappedValue>();
            for (String k : inputs.keySet()) {
                ConnectApi.WrappedValue w = new ConnectApi.WrappedValue();
                w.value = inputs.get(k);
                input.inputParams.put('Input:' + k, w);
            }
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation r =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE, input);
            return r.generations[0].text;
        }
    }

    // Résout le template en mode aperçu (sans appeler le modèle) : null si le template est actif et utilisable.
    public static String checkTemplate() {
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = true;
            input.inputParams = new Map<String, ConnectApi.WrappedValue>();
            for (String k : new List<String>{'objectJson', 'fieldsJson', 'sampleJson', 'orgLanguage'}) {
                ConnectApi.WrappedValue w = new ConnectApi.WrappedValue(); w.value = '{}';
                input.inputParams.put('Input:' + k, w);
            }
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE, input);
            return null;
        } catch (Exception e) { return e.getMessage(); }
    }

    public static List<AuditModels.Proposal> generate(String objectApiName, List<String> fieldApiNames, Integer sampleSize) {
        AuditModels.ObjectSnapshot snap = MetadataReader.readObject(objectApiName);
        Set<String> wanted = new Set<String>(fieldApiNames);
        List<AuditModels.FieldInfo> selected = new List<AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : snap.fields) { if (wanted.contains(f.apiName)) { selected.add(f); } }
        if (selected.isEmpty()) { return new List<AuditModels.Proposal>(); }

        Map<String, Decimal> fill = FillRateService.compute(objectApiName, selected);
        List<Map<String, String>> sample = SampleMasker.sample(objectApiName, selected, sampleSize);

        List<Map<String, Object>> fieldsPayload = payload(selected, snap.fields, fill);
        Map<String, String> inputs = new Map<String, String>{
            'objectJson' => JSON.serialize(new Map<String, Object>{'apiName' => snap.obj.apiName, 'label' => snap.obj.label, 'isCustom' => snap.obj.isCustom}),
            'fieldsJson' => JSON.serialize(fieldsPayload),
            'sampleJson' => JSON.serialize(sample),
            'orgLanguage' => [SELECT LanguageLocaleKey FROM Organization LIMIT 1].LanguageLocaleKey
        };
        String answer = runner.run(inputs);
        Map<String, AuditModels.FieldInfo> byName = new Map<String, AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : selected) { byName.put(f.apiName, f); }
        return parse(answer, byName, fill);
    }

    // Champs du lot envoyés au modèle, avec pour chacun ses champs « jumeaux » (même libellé ou même nom d'API de base)
    // pris sur TOUT l'objet : un jumeau peut se trouver hors du lot analysé.
    @TestVisible static List<Map<String, Object>> payload(List<AuditModels.FieldInfo> selected, List<AuditModels.FieldInfo> all, Map<String, Decimal> fill) {
        Map<String, List<AuditModels.FieldInfo>> similar = findSimilar(all);
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (AuditModels.FieldInfo f : selected) {
            List<Map<String, Object>> twins = new List<Map<String, Object>>();
            for (AuditModels.FieldInfo t : similar.containsKey(f.apiName) ? similar.get(f.apiName) : new List<AuditModels.FieldInfo>()) {
                twins.add(new Map<String, Object>{ 'apiName' => t.apiName, 'label' => t.label, 'isCustom' => t.isCustom, 'type' => t.type, 'description' => t.description });
            }
            out.add(new Map<String, Object>{
                'apiName' => f.apiName, 'label' => f.label, 'type' => f.type, 'description' => f.description,
                'inlineHelpText' => f.helpText, 'isCustom' => f.isCustom, 'isManaged' => f.isManaged,
                'isRequired' => f.isRequired, 'formula' => f.formula, 'referenceTo' => f.referenceTo,
                'picklistValues' => f.picklistValues.size() > 15 ? new List<String>(slice(f.picklistValues, 15)) : f.picklistValues,
                'fillRate' => fill.get(f.apiName), 'similarFields' => twins
            });
        }
        return out;
    }

    // Champs proches : même libellé normalisé, ou même nom d'API de base (sans __c ni underscores). Au moins un des deux est custom.
    @TestVisible static Map<String, List<AuditModels.FieldInfo>> findSimilar(List<AuditModels.FieldInfo> all) {
        Map<String, List<AuditModels.FieldInfo>> byKey = new Map<String, List<AuditModels.FieldInfo>>();
        for (AuditModels.FieldInfo f : all) {
            for (String key : new Set<String>{ 'L:' + norm(f.label), 'A:' + norm(f.apiName.removeEnd('__c')) }) {
                if (key.length() <= 2) { continue; }
                if (!byKey.containsKey(key)) { byKey.put(key, new List<AuditModels.FieldInfo>()); }
                byKey.get(key).add(f);
            }
        }
        Map<String, List<AuditModels.FieldInfo>> out = new Map<String, List<AuditModels.FieldInfo>>();
        for (List<AuditModels.FieldInfo> bucket : byKey.values()) {
            if (bucket.size() < 2) { continue; }
            for (AuditModels.FieldInfo a : bucket) {
                for (AuditModels.FieldInfo b : bucket) {
                    if (a.apiName == b.apiName || (a.isCustom != true && b.isCustom != true)) { continue; }
                    if (!out.containsKey(a.apiName)) { out.put(a.apiName, new List<AuditModels.FieldInfo>()); }
                    Boolean known = false;
                    for (AuditModels.FieldInfo k : out.get(a.apiName)) { if (k.apiName == b.apiName) { known = true; } }
                    if (!known) { out.get(a.apiName).add(b); }
                }
            }
        }
        return out;
    }

    private static String norm(String s) {
        return s == null ? '' : s.toLowerCase().replaceAll('[^a-z0-9]', '');
    }

    @TestVisible static List<AuditModels.Proposal> parse(String text, Map<String, AuditModels.FieldInfo> byName, Map<String, Decimal> fill) {
        String payload = text == null ? null : text.substringAfter('{') == '' ? null : '{' + text.substringAfter('{').substringBeforeLast('}') + '}';
        List<Object> items;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(payload);
            items = (List<Object>) root.get('items');
        } catch (Exception e) { items = null; }
        if (items == null) { throw new AuraHandledException('Réponse du modèle invalide pour ce lot de champs : réessayez ou réduisez la sélection.'); }

        List<AuditModels.Proposal> out = new List<AuditModels.Proposal>();
        Integer id = 1;
        for (Object o : items) {
            Map<String, Object> m = (Map<String, Object>) o;
            String field = (String) m.get('field'), attr = (String) m.get('attribute');
            String proposed = (String) m.get('proposed'), status = (String) m.get('status');
            AuditModels.FieldInfo f = byName.get(field);
            if (f == null || f.isManaged == true || String.isBlank(proposed) || !ATTRIBUTES.contains(attr) || !STATUSES.contains(status)) { continue; }
            if (attr == 'label' && f.isCustom != true) { continue; }
            Integer max = LIMITS.get(attr);
            if (attr == 'label' && proposed.length() > max) { continue; }
            if (proposed.length() > max) { proposed = proposed.left(max); }
            String current = attr == 'description' ? f.description : attr == 'inlineHelpText' ? f.helpText : f.label;
            if (current != null && current.equals(proposed)) { continue; }
            AuditModels.Proposal p = new AuditModels.Proposal();
            p.id = id++; p.level = 'field'; p.field = field; p.fieldIsCustom = f.isCustom; p.attribute = attr;
            p.current = current; p.proposed = proposed; p.status = status; p.fillRate = fill.get(field); p.apply = true;
            out.add(p);
        }
        return out;
    }

    private static List<String> slice(List<String> l, Integer n) {
        List<String> r = new List<String>();
        for (Integer i = 0; i < Math.min(n, l.size()); i++) { r.add(l[i]); }
        return r;
    }
}
