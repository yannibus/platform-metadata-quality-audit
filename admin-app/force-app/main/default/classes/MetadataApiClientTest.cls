@IsTest
private class MetadataApiClientTest {
    public static String lastUpdateBody;
    public static Integer calls = 0;
    private static String readResponse(String fullName) {
        return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><readMetadataResponse><result>'
            + '<records xsi:type="CustomField"><fullName>' + fullName + '</fullName><label>Old</label><type>Picklist</type><description>vieux</description>'
            + '<inlineHelpText>aide conservée</inlineHelpText><trackHistory>true</trackHistory>'
            + '<valueSet><valueSetDefinition><value><fullName>Hot</fullName><label>Hot</label></value></valueSetDefinition></valueSet></records></result></readMetadataResponse></soapenv:Body></soapenv:Envelope>';
    }
    private static String updateResponse(Boolean ok, String field, String msg) {
        return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://soap.sforce.com/2006/04/metadata"><soapenv:Body><updateMetadataResponse><result>'
            + (ok ? '' : '<errors><message>' + msg + '</message><statusCode>FIELD_INTEGRITY_EXCEPTION</statusCode></errors>')
            + '<fullName>' + field + '</fullName><success>' + ok + '</success></result></updateMetadataResponse></soapenv:Body></soapenv:Envelope>';
    }
    private class Mock implements HttpCalloutMock {
        Boolean updateOk; String field; String msg;
        Mock(Boolean updateOk, String field, String msg) { this.updateOk = updateOk; this.field = field; this.msg = msg; }
        public HttpResponse respond(HttpRequest req) {
            calls++;
            HttpResponse r = new HttpResponse(); r.setStatusCode(200);
            if (req.getBody().contains('<met:readMetadata>')) { r.setBody(readResponse(field)); }
            else { lastUpdateBody = req.getBody(); r.setBody(updateResponse(updateOk, field, msg)); }
            return r;
        }
    }
    private static AuditModels.Proposal p(Integer id, String field, Boolean custom, String attr, String text) {
        AuditModels.Proposal x = new AuditModels.Proposal(); x.id = id; x.level = 'field'; x.field = field; x.fieldIsCustom = custom; x.attribute = attr; x.proposed = text; x.apply = true; return x;
    }
    @IsTest static void update_escapesXmlSpecialChars() {
        Test.setMock(HttpCalloutMock.class, new Mock(true, 'Account.A__c', null));
        Test.startTest();
        MetadataApiClient.writeProposals('Account', new List<AuditModels.Proposal>{ p(1, 'A__c', true, 'description', 'R&D <Sud> l\'Est') });
        Test.stopTest();
        System.assert(lastUpdateBody.contains('R&amp;D &lt;Sud&gt;'), lastUpdateBody);
        System.assert(!lastUpdateBody.contains('R&D <Sud>'));
    }
    @IsTest static void update_preservesPicklistValueLabelsAndReplacesTopLevelLabelOnce() {
        Test.setMock(HttpCalloutMock.class, new Mock(true, 'Account.A__c', null));
        Test.startTest();
        MetadataApiClient.writeProposals('Account', new List<AuditModels.Proposal>{ p(1, 'A__c', true, 'label', 'Nouveau') });
        Test.stopTest();
        System.assert(lastUpdateBody.contains('<met:label>Nouveau</met:label>'));
        System.assert(!lastUpdateBody.contains('<met:label>Old</met:label>'));
        System.assert(lastUpdateBody.contains('<met:label>Hot</met:label>'), 'libellé de valeur de picklist conservé');
        System.assert(lastUpdateBody.contains('<met:type>Picklist</met:type>'), 'définition complète renvoyée');
        System.assert(lastUpdateBody.contains('<met:description>vieux</met:description>'), 'attribut non approuvé conservé');
    }
    @IsTest static void update_standardFieldReadsFullDefinitionFirstAndKeepsOtherAttributes() {
        calls = 0;
        Test.setMock(HttpCalloutMock.class, new Mock(true, 'Account.Industry', null));
        Test.startTest();
        MetadataApiClient.writeProposals('Account', new List<AuditModels.Proposal>{ p(1, 'Industry', false, 'description', 'Secteur') });
        Test.stopTest();
        System.assertEquals(2, calls, 'readMetadata puis updateMetadata, même pour un champ standard');
        System.assert(lastUpdateBody.contains('<met:inlineHelpText>aide conservée</met:inlineHelpText>'), 'updateMetadata remplace tout : l\'aide ne doit pas être effacée');
        System.assert(lastUpdateBody.contains('<met:trackHistory>true</met:trackHistory>'));
        System.assert(lastUpdateBody.contains('<met:description>Secteur</met:description>'));
    }
    @IsTest static void update_reportsExactErrorMessage() {
        Test.setMock(HttpCalloutMock.class, new Mock(false, 'Account.Industry', 'Could not resolve it'));
        Test.startTest();
        List<AuditModels.ApplyResult> r = MetadataApiClient.writeProposals('Account', new List<AuditModels.Proposal>{ p(7, 'Industry', false, 'description', 'x') });
        Test.stopTest();
        System.assertEquals('FAILED', r[0].status);
        System.assertEquals(7, r[0].id);
        System.assertEquals('Could not resolve it', r[0].message);
    }

    @IsTest static void update_neutralizesMergeFieldsInValues() {
        Test.setMock(HttpCalloutMock.class, new Mock(true, 'Account.A__c', null));
        Test.startTest();
        MetadataApiClient.writeProposals('Account', new List<AuditModels.Proposal>{ p(1, 'A__c', true, 'inlineHelpText', 'Voir {!$Credential.OAuthToken}') });
        Test.stopTest();
        System.assertEquals(1, lastUpdateBody.countMatches('{!$Credential.OAuthToken}'), 'seul l\'en-tête sessionId doit contenir le merge field');
        System.assert(lastUpdateBody.contains('{&#33;$Credential.OAuthToken}'), 'le texte est conservé, avec le « ! » encodé');
    }
}
