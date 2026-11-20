public with sharing class MetadataApiClient {
    private static final String ENDPOINT = 'callout:Metadata_API_Self/services/Soap/m/68.0';
    private static final String XSI = 'http://www.w3.org/2001/XMLSchema-instance';
    private static final Integer BATCH = 10;
    private static final Map<String, String> ELEMENT = new Map<String, String>{'description' => 'description', 'inlineHelpText' => 'inlineHelpText', 'label' => 'label'};

    // Écrit les propositions via updateMetadata. Champ custom : définition complète relue puis renvoyée modifiée
    // (updateMetadata remplace tout). Champ standard : fullName + attributs modifiés seulement.
    public static List<AuditModels.ApplyResult> writeProposals(String objectApiName, List<AuditModels.Proposal> items) {
        List<String> order = new List<String>();
        Map<String, List<AuditModels.Proposal>> byField = new Map<String, List<AuditModels.Proposal>>();
        for (AuditModels.Proposal p : items) {
            if (!byField.containsKey(p.field)) { byField.put(p.field, new List<AuditModels.Proposal>()); order.add(p.field); }
            byField.get(p.field).add(p);
        }
        List<AuditModels.ApplyResult> results = new List<AuditModels.ApplyResult>();
        for (Integer i = 0; i < order.size(); i += BATCH) {
            List<String> part = new List<String>();
            for (Integer j = i; j < Math.min(i + BATCH, order.size()); j++) { part.add(order[j]); }
            results.addAll(updateBatch(objectApiName, part, byField));
        }
        return results;
    }

    // Appel léger (describeMetadata) : null si la Named Credential et l'authentification de l'utilisateur fonctionnent.
    public static String ping() {
        try { call('<met:describeMetadata><met:asOfVersion>68.0</met:asOfVersion></met:describeMetadata>'); return null; }
        catch (Exception e) { return e.getMessage(); }
    }

    private static List<AuditModels.ApplyResult> updateBatch(String obj, List<String> fields, Map<String, List<AuditModels.Proposal>> byField) {
        List<AuditModels.ApplyResult> out = new List<AuditModels.ApplyResult>();
        try {
            // updateMetadata REMPLACE la définition, standard comme custom : on relit toujours la définition complète
            // (constaté en réel : écrire la seule description d'Account.Industry effaçait son inlineHelpText).
            List<String> allNames = new List<String>();
            for (String f : fields) { allNames.add(obj + '.' + f); }
            Map<String, Dom.XmlNode> definitions = readDefinitions(allNames);

            String metadata = '';
            for (String f : fields) {
                String full = obj + '.' + f;
                Map<String, String> overrides = new Map<String, String>();
                for (AuditModels.Proposal p : byField.get(f)) { overrides.put(ELEMENT.get(p.attribute), p.proposed); }
                String body = '';
                Dom.XmlNode def = definitions.get(full);
                if (def == null) { throw new CalloutException('Définition introuvable pour ' + full); }
                for (Dom.XmlNode c : def.getChildElements()) {
                    if (!overrides.containsKey(local(c.getName()))) { body += serialize(c); }
                }
                for (String k : overrides.keySet()) { body += '<met:' + k + '>' + xmlText(overrides.get(k)) + '</met:' + k + '>'; }
                metadata += '<met:metadata xsi:type="met:CustomField">' + body + '</met:metadata>';
            }
            Dom.Document resp = call('<met:updateMetadata>' + metadata + '</met:updateMetadata>');
            Map<String, String> status = new Map<String, String>();
            Dom.XmlNode root = find(resp.getRootElement(), 'updateMetadataResponse');
            for (Dom.XmlNode r : root.getChildElements()) {
                String full = text(r, 'fullName');
                Boolean ok = text(r, 'success') == 'true';
                String msg = null;
                Dom.XmlNode errors = child(r, 'errors');
                if (errors != null) { msg = text(errors, 'message'); }
                status.put(full, ok ? 'OK' : (msg == null ? 'Échec sans message' : msg));
            }
            for (String f : fields) {
                String s = status.get(obj + '.' + f);
                for (AuditModels.Proposal p : byField.get(f)) { out.add(result(p.id, s == 'OK' ? 'APPLIED' : 'FAILED', s == 'OK' ? null : (s == null ? 'Aucune réponse pour ce champ' : s))); }
            }
        } catch (Exception e) {
            out = new List<AuditModels.ApplyResult>();
            for (String f : fields) { for (AuditModels.Proposal p : byField.get(f)) { out.add(result(p.id, 'FAILED', e.getMessage())); } }
        }
        return out;
    }

    private static Map<String, Dom.XmlNode> readDefinitions(List<String> fullNames) {
        String names = '';
        for (String n : fullNames) { names += '<met:fullNames>' + n + '</met:fullNames>'; }
        Dom.Document d = call('<met:readMetadata><met:type>CustomField</met:type>' + names + '</met:readMetadata>');
        Dom.XmlNode res = find(d.getRootElement(), 'result');
        Map<String, Dom.XmlNode> m = new Map<String, Dom.XmlNode>();
        for (Dom.XmlNode rec : res.getChildElements()) {
            if (local(rec.getName()) == 'records') { m.put(text(rec, 'fullName'), rec); }
        }
        return m;
    }

    private static Dom.Document call(String bodyContent) {
        String body = '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="' + XSI + '">'
            + '<soapenv:Header><met:SessionHeader><met:sessionId>{!$Credential.OAuthToken}</met:sessionId></met:SessionHeader></soapenv:Header>'
            + '<soapenv:Body>' + bodyContent + '</soapenv:Body></soapenv:Envelope>';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', '""');
        req.setBody(body);
        HttpResponse res = new Http().send(req);
        Dom.Document d = new Dom.Document();
        d.load(res.getBody());
        Dom.XmlNode fault = find(d.getRootElement(), 'faultstring');
        if (fault != null) { throw new CalloutException(fault.getText()); }
        if (res.getStatusCode() != 200) { throw new CalloutException('HTTP ' + res.getStatusCode()); }
        return d;
    }

    // Échappe le XML ET neutralise les merge fields : la Named Credential évalue {!...} sur tout le corps de la requête,
    // une valeur contenant {!$Credential.OAuthToken} ferait écrire le jeton dans la métadonnée.
    @TestVisible static String xmlText(String s) {
        return s == null ? '' : s.escapeXml().replace('{!', '{&#33;');
    }

    private static AuditModels.ApplyResult result(Integer id, String status, String message) {
        AuditModels.ApplyResult r = new AuditModels.ApplyResult();
        r.id = id; r.status = status; r.message = message; r.verified = false;
        return r;
    }
    private static String local(String n) { return n != null && n.contains(':') ? n.substringAfter(':') : n; }
    private static Dom.XmlNode child(Dom.XmlNode n, String name) {
        for (Dom.XmlNode c : n.getChildElements()) { if (local(c.getName()) == name) { return c; } }
        return null;
    }
    private static String text(Dom.XmlNode n, String name) {
        Dom.XmlNode c = child(n, name);
        return c == null ? null : c.getText();
    }
    private static Dom.XmlNode find(Dom.XmlNode n, String name) {
        if (local(n.getName()) == name) { return n; }
        for (Dom.XmlNode c : n.getChildElements()) {
            Dom.XmlNode f = find(c, name);
            if (f != null) { return f; }
        }
        return null;
    }
    private static String serialize(Dom.XmlNode n) {
        String name = local(n.getName());
        if (n.getAttribute('nil', XSI) == 'true') { return ''; }
        List<Dom.XmlNode> kids = n.getChildElements();
        if (kids.isEmpty()) {
            String t = n.getText();
            return String.isEmpty(t) ? '' : '<met:' + name + '>' + xmlText(t) + '</met:' + name + '>';
        }
        String s = '';
        for (Dom.XmlNode k : kids) { s += serialize(k); }
        return '<met:' + name + '>' + s + '</met:' + name + '>';
    }
}
