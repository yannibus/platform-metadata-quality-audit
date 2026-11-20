@IsTest
private class SetupCheckerTest {
    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(200);
            r.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><describeMetadataResponse/></soapenv:Body></soapenv:Envelope>');
            return r;
        }
    }
    private class FaultMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(500);
            r.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><soapenv:Fault><faultcode>x</faultcode><faultstring>INVALID_SESSION_ID</faultstring></soapenv:Fault></soapenv:Body></soapenv:Envelope>');
            return r;
        }
    }
    private static SetupChecker.Check byCode(List<SetupChecker.Check> l, String code) {
        for (SetupChecker.Check c : l) { if (c.code == code) { return c; } }
        return null;
    }
    @IsTest static void run_reportsMissingNamedCredentialWithAction() {
        SetupChecker.namedCredentialExistsOverride = false;
        List<SetupChecker.Check> l = SetupChecker.run();
        System.assertEquals(false, byCode(l, 'namedCredential').ok);
        System.assert(byCode(l, 'namedCredential').action.contains('Named Credential'));
        System.assertEquals(false, byCode(l, 'metadataApi').ok);
    }
    @IsTest static void run_metadataApiOkWhenPingSucceeds() {
        SetupChecker.namedCredentialExistsOverride = true;
        Test.setMock(HttpCalloutMock.class, new OkMock());
        System.assertEquals(true, byCode(SetupChecker.run(), 'metadataApi').ok);
    }
    @IsTest static void run_metadataApiKoWithActionWhenFault() {
        SetupChecker.namedCredentialExistsOverride = true;
        Test.setMock(HttpCalloutMock.class, new FaultMock());
        SetupChecker.Check c = byCode(SetupChecker.run(), 'metadataApi');
        System.assertEquals(false, c.ok);
        System.assert(c.action.contains('INVALID_SESSION_ID'));
    }
}
