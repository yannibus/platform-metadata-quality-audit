public with sharing class MetadataReader {
    private static final Pattern MANAGED = Pattern.compile('^[A-Za-z][A-Za-z0-9]*__[A-Za-z0-9_]+__[A-Za-z]+$');

    public static Boolean isManaged(String apiName) {
        return apiName != null && MANAGED.matcher(apiName).matches();
    }

    private static final List<String> TECHNICAL_SUFFIXES = new List<String>{'__Share', '__History', '__Feed', '__ChangeEvent', 'ChangeEvent', '__e',
        '__mdt', '__x', '__b', '__dlm', '__dll', '__dmo', '__cio', '__chn', '__hd', '__tag', '__kav'};

    // Objets techniques (partage, historique, événements, Data Cloud, externes) : hors périmètre de l'audit.
    @TestVisible static Boolean isTechnical(String apiName) {
        for (String s : TECHNICAL_SUFFIXES) { if (apiName.endsWith(s)) { return true; } }
        return false;
    }

    public static List<AuditModels.FieldInfo> sortFields(List<AuditModels.FieldInfo> fields) {
        List<AuditModels.FieldInfo> custom = new List<AuditModels.FieldInfo>();
        List<AuditModels.FieldInfo> standard = new List<AuditModels.FieldInfo>();
        for (AuditModels.FieldInfo f : fields) {
            if (f.isCustom == true) { custom.add(f); } else { standard.add(f); }
        }
        custom.addAll(standard);
        return custom;
    }

    public static List<AuditModels.ObjectInfo> listObjects() {
        List<AuditModels.ObjectInfo> out = new List<AuditModels.ObjectInfo>();
        for (Schema.SObjectType t : Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult d = t.getDescribe();
            String n = d.getName();
            if (!d.isAccessible() || !d.isQueryable() || !d.isCreateable() || !d.isUpdateable() || isTechnical(n)) { continue; }
            out.add(toObjectInfo(d, null));
        }
        out.sort(new ObjectLabelComparator());
        return out;
    }

    public static AuditModels.ObjectSnapshot readObject(String objectApiName) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectApiName);
        if (t == null) { throw new AuraHandledException('Objet introuvable ou inaccessible : ' + objectApiName); }
        Schema.DescribeSObjectResult d = t.getDescribe();

        Map<String, String> descriptions = new Map<String, String>();
        Set<String> allNames = new Set<String>();
        // FieldDefinition ne supporte pas queryMore() : une seule requête, avec LIMIT.
        List<FieldDefinition> defs = [SELECT QualifiedApiName, Description FROM FieldDefinition
                                      WHERE EntityDefinition.QualifiedApiName = :objectApiName LIMIT 2000];
        for (FieldDefinition fd : defs) {
            descriptions.put(fd.QualifiedApiName, fd.Description);
            allNames.add(fd.QualifiedApiName);
        }
        // EntityDefinition.Description n'est pas lisible en SOQL standard : lecture via Tooling API (Named Credential) après le spike de la Task 0.
        String objDescription = null;

        AuditModels.ObjectSnapshot s = new AuditModels.ObjectSnapshot();
        s.obj = toObjectInfo(d, objDescription);
        List<AuditModels.FieldInfo> fields = new List<AuditModels.FieldInfo>();
        Set<String> seen = new Set<String>();
        for (Schema.SObjectField sf : d.fields.getMap().values()) {
            Schema.DescribeFieldResult fr = sf.getDescribe();
            AuditModels.FieldInfo f = new AuditModels.FieldInfo();
            f.apiName = fr.getName();
            f.label = fr.getLabel();
            f.type = String.valueOf(fr.getType());
            f.helpText = fr.getInlineHelpText();
            f.description = descriptions.get(f.apiName);
            f.isCustom = fr.isCustom();
            f.isManaged = isManaged(f.apiName);
            f.isRequired = !fr.isNillable() && !fr.isDefaultedOnCreate();
            f.formula = fr.getCalculatedFormula();
            for (Schema.SObjectType r : fr.getReferenceTo()) { f.referenceTo.add(String.valueOf(r)); }
            for (Schema.PicklistEntry pe : fr.getPicklistValues()) { if (pe.isActive()) { f.picklistValues.add(pe.getLabel()); } }
            fields.add(f);
            seen.add(f.apiName);
        }
        Integer hidden = 0;
        for (String n : allNames) { if (!seen.contains(n)) { hidden++; } }
        s.obj.hiddenFieldCount = hidden;
        s.fields = sortFields(fields);
        return s;
    }

    private static AuditModels.ObjectInfo toObjectInfo(Schema.DescribeSObjectResult d, String description) {
        AuditModels.ObjectInfo o = new AuditModels.ObjectInfo();
        o.apiName = d.getName();
        o.label = d.getLabel();
        o.pluralLabel = d.getLabelPlural();
        o.description = description;
        o.isCustom = d.isCustom();
        o.isManaged = isManaged(o.apiName);
        return o;
    }

    private class ObjectLabelComparator implements System.Comparator<AuditModels.ObjectInfo> {
        public Integer compare(AuditModels.ObjectInfo a, AuditModels.ObjectInfo b) {
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        }
    }
}
