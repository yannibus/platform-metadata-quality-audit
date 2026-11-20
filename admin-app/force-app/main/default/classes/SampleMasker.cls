public with sharing class SampleMasker {
    // Noms d'API et libellés, en anglais et en français. Le motif court « nir » n'est reconnu qu'en mot isolé.
    private static final Pattern SENSITIVE = Pattern.compile('(?i).*(email|e-mail|mail|phone|mobile|telephone|portable|ssn|iban|bic|birth|naissance|address|adresse|salary|salaire|remuneration|passport|passeport|tax|impot|secu|social_sec|social sec|securite sociale|sécurité sociale|password|mot_de_passe|mdp|token|secret|cvv|carte|card|licen[cs]e|permis).*');
    private static final Pattern SENSITIVE_WORD = Pattern.compile('(?i)(^|[^a-z])nir([^a-z]|$)');
    private static final Set<String> SKIP_TYPES = new Set<String>{'ADDRESS', 'LOCATION', 'BASE64', 'ENCRYPTEDSTRING'};
    private static final Integer MAX_COLUMNS = 40;

    private static Boolean matches(String name) {
        return name != null && (SENSITIVE.matcher(name).matches() || SENSITIVE_WORD.matcher(name).find());
    }

    public static Integer clamp(Integer n) {
        if (n == null) { return 25; }
        return Math.max(1, Math.min(100, n));
    }

    public static String mask(AuditModels.FieldInfo f, Object value) {
        if (value == null) { return null; }
        String s = String.valueOf(value);
        Boolean sensitive = f.type == 'EMAIL' || f.type == 'PHONE' || f.type == 'ENCRYPTEDSTRING'
            || matches(f.apiName) || matches(f.label);
        if (sensitive) { return s.left(2) + '***'; }
        return s.length() > 60 ? s.left(60) : s;
    }

    // Ordre commun à l'échantillon et au taux de remplissage : les enregistrements les plus récemment mis à jour d'abord
    // (Id DESC en départage, ou seul critère pour un objet sans LastModifiedDate).
    public static String recentOrder(Map<String, Schema.SObjectField> fieldMap) {
        return fieldMap.containsKey('LastModifiedDate') ? 'LastModifiedDate DESC, Id DESC' : 'Id DESC';
    }

    public static List<Map<String, String>> sample(String objectApiName, List<AuditModels.FieldInfo> fields, Integer size) {
        List<AuditModels.FieldInfo> cols = new List<AuditModels.FieldInfo>();
        Map<String, Schema.SObjectField> dm = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        for (AuditModels.FieldInfo f : fields) {
            if (cols.size() >= MAX_COLUMNS) { break; }
            if (SKIP_TYPES.contains(f.type) || !dm.containsKey(f.apiName)) { continue; }
            if (!dm.get(f.apiName).getDescribe().isAccessible()) { continue; }
            cols.add(f);
        }
        if (cols.isEmpty()) { return new List<Map<String, String>>(); }
        List<String> names = new List<String>();
        for (AuditModels.FieldInfo f : cols) { names.add(f.apiName); }
        String soql = 'SELECT ' + String.join(names, ',') + ' FROM ' + objectApiName
            + ' ORDER BY ' + recentOrder(dm) + ' LIMIT ' + clamp(size);
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (SObject r : Database.query(soql)) {
            Map<String, String> row = new Map<String, String>();
            for (AuditModels.FieldInfo f : cols) { row.put(f.apiName, mask(f, r.get(f.apiName))); }
            rows.add(row);
        }
        return rows;
    }
}
