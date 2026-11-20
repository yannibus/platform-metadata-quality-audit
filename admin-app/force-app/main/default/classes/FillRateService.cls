public with sharing class FillRateService {
    private static final Integer COLUMNS_PER_QUERY = 50;
    // Taux calculé sur les N enregistrements les plus récents : un COUNT() sur tout l'objet dépasse
    // la limite de 50 000 lignes dès qu'un objet est volumineux (LimitException non interceptable).
    @TestVisible static Integer sampleRows = 2000;

    @TestVisible static List<List<String>> chunk(List<String> names, Integer size) {
        List<List<String>> out = new List<List<String>>();
        for (Integer i = 0; i < names.size(); i += size) {
            List<String> part = new List<String>();
            for (Integer j = i; j < Math.min(i + size, names.size()); j++) { part.add(names[j]); }
            out.add(part);
        }
        return out;
    }

    // Clé = API name ; valeur 0–1, ou null si non mesurable (n/a) ou objet vide.
    public static Map<String, Decimal> compute(String objectApiName, List<AuditModels.FieldInfo> fields) {
        Map<String, Decimal> result = new Map<String, Decimal>();
        Map<String, Schema.SObjectField> dm = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        List<String> measurable = new List<String>();
        for (AuditModels.FieldInfo f : fields) {
            result.put(f.apiName, null);
            if (!dm.containsKey(f.apiName)) { continue; }
            Schema.DescribeFieldResult d = dm.get(f.apiName).getDescribe();
            Schema.DisplayType t = d.getType();
            Boolean longText = t == Schema.DisplayType.TEXTAREA && d.getLength() > 255;
            if (d.isAccessible() && !longText && t != Schema.DisplayType.ADDRESS && t != Schema.DisplayType.LOCATION
                && t != Schema.DisplayType.BASE64 && t != Schema.DisplayType.ENCRYPTEDSTRING && t != Schema.DisplayType.ANYTYPE) {
                measurable.add(f.apiName);
            }
        }
        for (List<String> part : chunk(measurable, COLUMNS_PER_QUERY)) {
            List<SObject> rows = Database.query('SELECT ' + String.join(part, ',') + ' FROM ' + objectApiName + ' ORDER BY Id DESC LIMIT ' + sampleRows);
            if (rows.isEmpty()) { continue; }
            for (String name : part) {
                Integer filled = 0;
                for (SObject r : rows) {
                    Object v = r.get(name);
                    if (v != null && !(v instanceof String && String.isEmpty((String) v))) { filled++; }
                }
                result.put(name, Decimal.valueOf(filled).divide(rows.size(), 4));
            }
        }
        return result;
    }
}
