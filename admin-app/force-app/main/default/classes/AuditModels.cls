public with sharing class AuditModels {
    public class FieldInfo {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public String description;
        @AuraEnabled public String helpText;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public Boolean isManaged;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public String formula;
        @AuraEnabled public List<String> referenceTo = new List<String>();
        @AuraEnabled public List<String> picklistValues = new List<String>();
    }
    public class ObjectInfo {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String pluralLabel;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public Boolean isManaged;
        @AuraEnabled public Integer hiddenFieldCount = 0;
    }
    public class ObjectSnapshot {
        @AuraEnabled public ObjectInfo obj;
        @AuraEnabled public List<FieldInfo> fields = new List<FieldInfo>();
    }
    public class Proposal {
        @AuraEnabled public Integer id;
        @AuraEnabled public String level;
        @AuraEnabled public String field;
        @AuraEnabled public Boolean fieldIsCustom;
        @AuraEnabled public String attribute;
        @AuraEnabled public String current;
        @AuraEnabled public String proposed;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal fillRate;
        @AuraEnabled public Boolean apply;
    }
    public class ApplyResult {
        @AuraEnabled public Integer id;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public Boolean verified;
    }
    public class ApplyReport {
        @AuraEnabled public List<ApplyResult> results = new List<ApplyResult>();
        @AuraEnabled public Integer applied = 0;
        @AuraEnabled public Integer skipped = 0;
        @AuraEnabled public Integer failed = 0;
    }
}
