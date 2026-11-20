# LWC d'audit des métadonnées — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** Livrer le flux « Admin » du dépôt : un LWC (page unique) qui audite les descriptions, aides et libellés d'un objet, génère des propositions par Prompt Template, et les applique via la Metadata API.

**Architecture :** LWC → contrôleur Apex `MetadataAuditController` → services Apex spécialisés. Lecture par `describe` + SOQL `FieldDefinition`. Génération par Prompt Template Flex. Écriture par SOAP `updateMetadata` via une Named Credential en boucle, External Credential à principal par utilisateur.

**Tech Stack :** Salesforce API 68.0, LWC, Apex, Prompt Builder (Flex template), Named/External Credential, unlocked package sans namespace.

**Spec :** `docs/superpowers/specs/2026-11-19-lwc-admin-design.md`

## Global Constraints

- API version `68.0` ; org de test `org-de-test` (Enterprise, `en_US`).
- Échantillon : entier de 1 à 100, défaut 25.
- Limites : description champ 1000 caractères, aide 510, libellé champ 40, libellé objet 80 ; cible 20–150 (champ), 250 (objet).
- Libellés : custom uniquement (objets et champs), jamais sur standard. Composants à espace de noms = `MANAGED`, jamais modifiés.
- Masquage avant tout appel au modèle : types email, téléphone, chiffré et noms correspondant à `(?i)(email|phone|mobile|ssn|iban|birth|address|salary|passport|tax)` → 2 premiers caractères + `***` ; autres valeurs tronquées à 60.
- Un objet à la fois. Lots de champs, pas de Queueable.
- Langue : référence = `Organization.LanguageLocaleKey` ; si différente de `UserInfo.getLanguage()`, application bloquée ; le composant ne modifie jamais la langue de l'utilisateur.
- Aucun secret dans le package. Identité d'écriture : principal par utilisateur.
- Pas de commit sauf demande explicite de l'utilisateur (mode de travail local) : les étapes « Commit » sont à sauter.
- Textes de l'interface en français ; code et noms en anglais.

## Review Focus

1. Objet sans enregistrement : taux de remplissage `null`/`n/a`, pas de division par zéro ni d'échantillon vide envoyé au modèle.
2. Valeurs contenant `& < > '` ou des guillemets : XML SOAP échappé, sinon écriture refusée ou corrompue.
3. Réponse du modèle en JSON invalide ou incomplète : lot ignoré avec message, pas de plantage ni de proposition vide appliquée.
4. Champs invisibles pour l'utilisateur ou objet de plus de 100 champs : signalés dans le résumé, ordre custom d'abord.
5. Langue de l'utilisateur différente de celle de l'org : bouton Appliquer bloqué avec explication, lecture autorisée.

---

### Task 0: Spike bloquant — écriture depuis Apex via Named Credential

**Files:**
- Create: `admin-app/force-app/main/default/classes/SpikeMetadataWrite.cls` (jetable)
- Create: `admin-app/force-app/main/default/externalCredentials/` et `namedCredentials/` du spike

**Interfaces:**
- Produces : décision go/no-go. Si go : l'enveloppe SOAP `updateMetadata` validée, réutilisée en Task 5.

- [ ] **Step 1 :** Dans `org-de-test`, créer une External Credential (protocole OAuth 2.0, principal par utilisateur) et une Named Credential `Metadata_API_Self` pointant sur `https://<my-domain>/services/Soap/m/68.0`. Authentifier l'utilisateur de test.
- [ ] **Step 2 :** Implémenter `SpikeMetadataWrite.run(String fullName, String description): String` qui envoie `updateMetadata` (type `CustomField`) et renvoie le corps de réponse.
- [ ] **Step 3 :** Exécuter en anonyme sur un champ custom de test puis sur `Account.Industry`. Attendu : `<success>true</success>` pour les deux ; relecture SOQL `FieldDefinition` = valeur envoyée.
- [ ] **Step 4 :** Remettre l'org dans son état initial (champ de test supprimé, `Industry` vidé), puis consigner le résultat dans `docs/superpowers/plans/spike-result.md`. **Si échec : arrêter le plan et rouvrir le design (repli approche C).**

### Task 1: Restructuration du dépôt et squelette SFDX

**Files:**
- Move: `SKILL.md`, `references/` → `skill/`
- Create: `admin-app/sfdx-project.json` (`sourceApiVersion` 68.0, package directory `force-app`), `admin-app/force-app/main/default/{classes,lwc,permissionsets}/`
- Modify: `README.md` (présente les deux flux)

**Interfaces:** Produces le squelette utilisé par toutes les tâches suivantes.

- [ ] **Step 1 :** `git mv` de la skill vers `skill/` ; mettre à jour les chemins relatifs cités dans `SKILL.md` si besoin.
- [ ] **Step 2 :** Créer le projet SFDX `admin-app/` et vérifier `sf project deploy start --dry-run --source-dir admin-app/force-app --target-org org-de-test` → succès (projet vide).
- [ ] **Step 3 :** Réécrire `README.md` : deux flux (vibe coders = `skill/`, admins = `admin-app/`), renvoi aux règles de référence dans `skill/SKILL.md`.

### Task 2: Lecture des métadonnées (`MetadataReader`)

**Files:**
- Create: `admin-app/.../classes/MetadataReader.cls`, `MetadataReaderTest.cls`, `AuditModels.cls` (DTO)

**Interfaces:**
- Produces :
  - `AuditModels.FieldInfo { String apiName; String label; String type; String description; String helpText; Boolean isCustom; Boolean isManaged; Boolean isRequired; String formula; List<String> referenceTo; List<String> picklistValues }`
  - `AuditModels.ObjectInfo { String apiName; String label; String pluralLabel; String description; Boolean isCustom; Boolean isManaged; Integer hiddenFieldCount }`
  - `MetadataReader.listObjects(): List<AuditModels.ObjectInfo>` (objets accessibles, triés par libellé)
  - `MetadataReader.readObject(String objectApiName): AuditModels.ObjectSnapshot { ObjectInfo obj; List<FieldInfo> fields }` (champs custom d'abord)

- [ ] **Step 1 :** Tests : `readObject_returnsDescriptionFromFieldDefinition`, `readObject_flagsNamespacedFieldAsManaged` (champ `ns__F__c`), `readObject_putsCustomFieldsFirst`, `readObject_unknownObject_throwsAuraHandledException`.
- [ ] **Step 2 :** Exécuter les tests → échec (classe absente).
- [ ] **Step 3 :** Implémenter : `Schema.describe` pour libellés, aide, type, formule, relations ; SOQL `FieldDefinition` (`QualifiedApiName`, `Description`) pour les descriptions ; `EntityDefinition.Description` pour l'objet, avec repli Tooling API via la Named Credential si la lecture SOQL renvoie `null` à tort (à confirmer dans le spike). `hiddenFieldCount` = champs de `FieldDefinition` absents du `describe`.
- [ ] **Step 4 :** `sf apex run test --class-names MetadataReaderTest --target-org org-de-test --synchronous` → tous verts.

### Task 3: Taux de remplissage et échantillon masqué

**Files:**
- Create: `FillRateService.cls`, `SampleMasker.cls` et leurs tests

**Interfaces:**
- Consumes : `AuditModels.FieldInfo`.
- Produces :
  - `FillRateService.compute(String objectApiName, List<AuditModels.FieldInfo> fields): Map<String, Decimal>` (clé = API name, valeur 0–1 ou `null` si `n/a` ou objet vide)
  - `SampleMasker.mask(AuditModels.FieldInfo f, Object value): String`
  - `SampleMasker.sample(String objectApiName, List<AuditModels.FieldInfo> fields, Integer size): List<Map<String,String>>` (size borné à 1–100)

- [ ] **Step 1 :** Tests : `compute_batchesAt50Aggregates`, `compute_emptyObject_returnsNull` (Review Focus 1), `compute_longTextField_returnsNull`, `mask_emailKeepsTwoCharsThenStars`, `mask_nameMatchingSensitivePattern`, `mask_truncatesOtherValuesTo60`, `sample_clampsSizeTo100`.
- [ ] **Step 2 :** Exécuter → échec.
- [ ] **Step 3 :** Implémenter : `COUNT(Id) total, COUNT(Field)…` par paquets de 50 ; types non comptables → `null` ; échantillon `ORDER BY LastModifiedDate DESC LIMIT :size`, uniquement champs lisibles.
- [ ] **Step 4 :** Tests → verts.

### Task 4: Génération par Prompt Template

**Files:**
- Create: `admin-app/.../genAiPromptTemplates/Metadata_Quality_Proposals.genAiPromptTemplate-meta.xml` (Flex, entrées `fieldsJson`, `sampleJson`, `orgLanguage`, `objectJson`), `ProposalGenerator.cls`, `ProposalGeneratorTest.cls`

**Interfaces:**
- Consumes : `FieldInfo`, `FillRateService.compute`, `SampleMasker.sample`.
- Produces :
  - `AuditModels.Proposal { Integer id; String level; String field; Boolean fieldIsCustom; String attribute; String current; String proposed; String status; Decimal fillRate; Boolean apply }`
  - `ProposalGenerator.generate(String objectApiName, List<String> fieldApiNames, Integer sampleSize): List<AuditModels.Proposal>`
  - Statuts : `MISSING`, `POOR`, `ADEQUATE`, `GOOD`, `MANAGED` ; `attribute` ∈ `description`, `inlineHelpText`, `label`, `pluralLabel`.

- [ ] **Step 1 :** Tests (appel au modèle simulé via une interface `PromptRunner` injectable) : `generate_parsesModelJson`, `generate_dropsProposalsOnManagedFields`, `generate_neverProposesLabelOnStandardField`, `generate_invalidJson_returnsErrorForBatchOnly` (Review Focus 3), `generate_truncatesProposalOver1000Chars`.
- [ ] **Step 2 :** Exécuter → échec.
- [ ] **Step 3 :** Rédiger le template à partir des critères de `skill/SKILL.md` (§3 Phase 3 : critères, règles de rédaction, règles de libellés), sortie JSON stricte. Implémenter `generate` : appel via `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`, parse JSON, filtrage.
- [ ] **Step 4 :** Tests → verts ; déployer le template sur `org-de-test` et vérifier qu'il s'affiche dans Prompt Builder (si Einstein Generative AI est absent de cette org, utiliser une org de dev qui l'a et le noter dans `spike-result.md`).

### Task 5: Application des propositions

**Files:**
- Create: `MetadataApiClient.cls`, `ProposalValidator.cls`, `LanguageGuard.cls`, `ProposalApplier.cls` et leurs tests

**Interfaces:**
- Consumes : `Proposal`, `MetadataReader.readObject`, enveloppe SOAP validée en Task 0.
- Produces :
  - `LanguageGuard.check(): LanguageGuard.Result { Boolean ok; String orgLanguage; String userLanguage }`
  - `ProposalValidator.validate(AuditModels.ObjectSnapshot s, List<Proposal> items): List<Proposal>` (retire lignes non cochées, vides, `MANAGED`, libellé sur standard, hors limites)
  - `MetadataApiClient.update(String objectApiName, List<Proposal> items): List<ApplyResult>` ; échappe `& < > " '`
  - `AuditModels.ApplyReport { List<ApplyResult> results; Integer applied; Integer skipped; Integer failed }` ; `ApplyResult { Integer id; String status; String message; Boolean verified }`
  - `ProposalApplier.apply(String objectApiName, List<Proposal> items): AuditModels.ApplyReport`

- [ ] **Step 1 :** Tests : `check_languageMismatch_returnsNotOk` (Review Focus 5), `apply_languageMismatch_throws`, `validate_dropsOverLimitAndManaged`, `update_escapesXmlSpecialChars` (Review Focus 2, valeur `R&D <Sud> l'Est`), `apply_verifiesEachValueAfterWrite`, `apply_reportsExactErrorMessage`. Appels HTTP simulés avec `HttpCalloutMock`.
- [ ] **Step 2 :** Exécuter → échec.
- [ ] **Step 3 :** Implémenter `apply` : contrôle langue → relecture des valeurs actuelles → `validate` → `MetadataApiClient.update` (un seul champ modifié par attribut approuvé, rien d'autre) → relecture `FieldDefinition`/`describe` et comparaison → rapport.
- [ ] **Step 4 :** Tests → verts ; test réel sur `org-de-test` : appliquer une proposition sur `Account.Industry`, vérifier la relecture, puis remettre à vide.

### Task 6: Contrôleur Apex et vérification de configuration

**Files:**
- Create: `MetadataAuditController.cls`, `SetupChecker.cls` et tests

**Interfaces:**
- Produces (`@AuraEnabled`, cacheable pour les lectures) :
  - `listObjects(): List<AuditModels.ObjectInfo>`
  - `readObject(String objectApiName): AuditModels.ObjectSnapshot`
  - `analyzeBatch(String objectApiName, List<String> fieldApiNames, Integer sampleSize): List<AuditModels.Proposal>`
  - `applyProposals(String objectApiName, List<AuditModels.Proposal> items): AuditModels.ApplyReport`
  - `checkSetup(): List<SetupChecker.Check { String code; String label; Boolean ok; String action }>` — contrôles : Named Credential, authentification de l'utilisateur, Prompt Template actif, permission set, appel de lecture Metadata API.
  - `languageStatus(): LanguageGuard.Result`

- [ ] **Step 1 :** Tests : `checkSetup_reportsMissingNamedCredentialWithAction`, `analyzeBatch_clampsSampleSize`, `listObjects_excludesInaccessibleObjects`.
- [ ] **Step 2 :** Implémenter en déléguant aux services ; exceptions converties en `AuraHandledException` avec message lisible.
- [ ] **Step 3 :** Tests → verts.

### Task 7: Composants LWC

**Files:**
- Create: `admin-app/.../lwc/metadataAuditApp/` (conteneur, sélection + progression), `auditResults/` (liste de propositions modifiables), `applyReport/`, `setupWizard/` (+ tests Jest)
- Create: FlexiPage App Page et onglet

**Interfaces:**
- Consumes : méthodes `@AuraEnabled` de Task 6.
- Produces : événements `analyze` (`{objectApiName, sampleSize}`), `selectionchange`, `apply`.

- [ ] **Step 1 :** Tests Jest : `sampleSize clamps to 1..100`, `analyze button disabled until object selected`, `apply button shows count of checked rows`, `apply disabled with message when language mismatch`, `edited proposal text is sent on apply`, `hidden-fields warning shown when hiddenFieldCount > 0`, `setupWizard shows action for each failing check`.
- [ ] **Step 2 :** Exécuter `npx jest` dans `admin-app/` → échec.
- [ ] **Step 3 :** Implémenter selon la maquette du design §5.1 : analyse par lots de champs avec barre de progression ; ligne de proposition avec case, statut, taux, valeur actuelle, texte éditable ; résumé (propositions, `MANAGED`, champs invisibles) ; styles SLDS.
- [ ] **Step 4 :** Jest → verts ; déployer et vérifier à l'écran dans `org-de-test` : parcours complet sur `Account` avec échantillon 10.

### Task 8: Package, permission set, documentation, recette

**Files:**
- Create: `permissionsets/Metadata_Quality_Audit_Admin.permissionset-meta.xml`, `admin-app/README.md`
- Modify: `admin-app/sfdx-project.json` (définition du package), `README.md`

**Interfaces:** Produces le package installable.

- [ ] **Step 1 :** Permission set : accès aux classes Apex, au composant, à l'External Credential (principal par utilisateur), au Prompt Template ; pas de droit d'écriture propre.
- [ ] **Step 2 :** Définir l'unlocked package sans namespace ; `sf package create` et première version bêta (confirmer avec l'utilisateur avant de créer le package dans le Dev Hub).
- [ ] **Step 3 :** `admin-app/README.md` : installation, assistant de configuration, limites connues (propre à l'objet, un objet à la fois, Einstein Generative AI requis).
- [ ] **Step 4 :** Recette manuelle sur une org vierge : installer, configurer via l'assistant, auditer un objet standard et un objet custom, appliquer, relire. Consigner les résultats dans `docs/superpowers/plans/recette.md`.

---

## Auto-revue

- **Couverture du design :** lecture (T2), mesure et masquage (T3), génération (T4), application, langue, vérification (T5), contrôleur et assistant de configuration (T6), UI et champs invisibles (T7), package et permission set (T8), structure du dépôt (T1), phase 0 bloquante (T0).
- **Cohérence des types :** `Proposal`, `ObjectSnapshot`, `ApplyReport` définis dans `AuditModels` (T2/T4/T5) et repris à l'identique en T6/T7.
- **Hors plan :** traduction, export Markdown, multi-objets, Queueable (non-objectifs du design).
