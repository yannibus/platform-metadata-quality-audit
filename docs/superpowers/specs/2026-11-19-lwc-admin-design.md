# Design — Flux « Admin » : LWC d'audit de la qualité des métadonnées

Date : 2026-11-19 · Statut : à approuver · Auteur : Yann Jourdain (avec Claude)

## 1. Intention et pourquoi

Le projet `platform-metadata-quality-audit` est aujourd'hui une skill d'agent (Claude Code, Agentforce Vibes) : elle suppose un agent, la CLI `sf` et un projet local. Les administrateurs d'org qui ne font pas de vibe coding n'y ont pas accès.

On ajoute un second flux, un **Lightning Web Component** que l'admin utilise directement dans son org, sans CLI ni agent. Le dépôt publié propose donc deux flux :

| Flux | Public | Moyen |
|------|--------|-------|
| `skill/` | Vibe coders | Skill d'agent + CLI `sf` (existant, v1.2) |
| `admin-app/` | Admins d'org | Package SFDX avec LWC + Apex + Prompt Template |

Les deux flux appliquent les mêmes règles métier (critères de qualité, périmètre, garde-fous). La génération de texte qui passe par Claude dans la skill passe par un **Prompt Template** dans le LWC.

## 2. Objectifs, non-objectifs, anti-objectifs

**Objectifs**
- Un admin choisit un objet et une taille d'échantillon (1 à 100), lance l'analyse, relit les propositions, les corrige et les applique, le tout dans une seule page.
- Même périmètre que la skill : `description` et `inlineHelpText` (champs standard et custom), `label` (champs custom et objet custom), `pluralLabel` (objet custom), `description` d'objet (standard et custom).
- Installation en un clic (unlocked package) puis un écran de configuration guidé.

**Non-objectifs (v1)**
- Plusieurs objets par exécution : un objet à la fois.
- Traduction des libellés (reste le rôle de l'agent `sf-metadata-translator`).
- Rapport exporté en Markdown ou JSON.
- Prise en charge des composants de package géré (listés `MANAGED`, jamais modifiés).

**Anti-objectifs** (échec même si cela « marche »)
- Écrire dans l'org sans action explicite de l'admin.
- Écraser des textes de référence par des traductions (voir §5, langue).
- Envoyer au modèle des valeurs sensibles non masquées.
- Rendre l'installation plus difficile que la skill.

## 3. Contraintes et constats (spike du 2026-11-19, org Enterprise, API 68.0)

- **Apex ne peut pas écrire les descriptions.** `Metadata.CustomField`, `Metadata.CustomObject` et `Metadata.MetadataType.CustomField` n'existent pas dans le namespace Apex `Metadata`. `Metadata.Operations` est donc écarté.
- **Lecture sans credentials.** `FieldDefinition.Description` se lit en SOQL standard depuis Apex. `EntityDefinition.Description` n'a pas été confirmé de la même façon (la requête filtrée par `QualifiedApiName` a renvoyé des valeurs nulles) : à vérifier, repli sur la Tooling API.
- **Écriture par la Metadata API confirmée**, y compris sur un champ standard (`Account.Industry`) : `description` et `inlineHelpText` ont persisté et se relisent par SOQL et `describe`. Testé par `sf project deploy`, pas encore depuis Apex.
- **Visibilité.** Un champ custom déployé existait côté Tooling API mais restait invisible en SOQL et en `describe` pour l'utilisateur System Administrator (droits de lecture non accordés à son profil). Un champ invisible échappe à l'audit.
- **Jeton de session.** Le jeton de session d'un utilisateur Lightning ne sert pas aux appels API depuis Apex ; il faut une Named Credential.

## 4. Approches envisagées

| | Approche | Verdict |
|--|----------|---------|
| A | Apex + Named Credential en boucle sur la même org, appels Metadata API (SOAP) pour l'écriture | **Retenue** |
| B | `Metadata.Operations` en Apex pur, sans credentials | Écartée : types non exposés (spike) |
| C | Lecture en Apex, écriture manuelle par l'admin (export, change set) | Écartée : perd le bouton « Appliquer » |

Choix de l'utilisateur : A, avec un assistant de configuration dans le composant.

## 5. Conception

### 5.1 Écran principal

Une page unique, trois zones :
1. **Sélection** : liste déroulante d'objets (standard et custom accessibles), champ « taille de l'échantillon » (1–100, défaut 25), bouton Analyser.
2. **Restitution** : résumé (nombre de propositions, éléments gérés, champs invisibles), puis une ligne par proposition : case à cocher, champ, attribut, statut (`MISSING` / `POOR` / `ADEQUATE`), taux de remplissage, valeur actuelle, valeur proposée **modifiable**.
3. **Application** : « Tout cocher », « Appliquer (n) », puis rapport de résultat : appliqué, ignoré, en échec avec le message exact, et relecture des valeurs.

### 5.2 Flux de données

1. **Lecture.** Apex lit les champs par `describe` (libellés, types, aide) et les descriptions par SOQL sur `FieldDefinition`. Les champs à espace de noms sont marqués `MANAGED`.
2. **Mesure.** Taux de remplissage par requêtes agrégées (50 `COUNT()` au plus par requête, `n/a` pour les types non comptables) et échantillon des N derniers enregistrements, valeurs sensibles masquées (2 premiers caractères + `***`, autres valeurs tronquées à 60).
3. **Génération.** Apex appelle un Prompt Template par lots de champs (taille de lot à fixer pendant l'implémentation selon la fenêtre du modèle). Le template reçoit libellés, types, formules, relations, valeurs de picklist, taux de remplissage et échantillon masqué ; il rend du JSON (id, attribut, proposition).
4. **Revue.** L'admin modifie ou décoche. Rien n'est écrit.
5. **Application.** Apex relit les valeurs actuelles, ne garde que les lignes cochées non vides, contrôle les longueurs (description champ 1000, aide 510, libellé champ 40, objet 80), exclut `MANAGED`, puis appelle la Metadata API via la Named Credential : `updateMetadata` limité aux attributs approuvés.
6. **Vérification.** Relecture par SOQL et `describe`, comparaison avec chaque valeur envoyée, rapport par ligne.

### 5.3 Règles reprises de la skill

- Critères de qualité : présent, précis, contexte métier, 20–150 caractères ; limites dures 1000 (description) et 510 (aide).
- Libellés uniquement sur objets et champs custom, et seulement si le libellé existant est défectueux ; avertissement que le renommage est visible des utilisateurs.
- Jamais de proposition de libellé sur un objet ou un champ standard.
- Objet de plus de 100 champs : traiter d'abord les champs custom, puis les standard dont le taux de remplissage dépasse 0 %, avec avertissement.
- Langue : les propositions sont écrites dans la langue de référence de l'org.
- **Contrôle de langue** : si la langue de l'utilisateur connecté diffère de celle de l'org, le composant bloque l'application et explique pourquoi (les libellés lus seraient des traductions, et les réécrire écraserait le texte de référence). Il propose de changer la langue de l'utilisateur ou de se reconnecter avec un autre utilisateur ; il ne modifie jamais cette langue lui-même.
- Champs invisibles pour l'utilisateur : signalés dans le résumé, avec la recommandation d'utiliser un profil disposant de « View All Fields ».

### 5.4 Assistant de configuration

Un écran « Configuration » vérifie et guide :
- la Named Credential (et son External Credential / Connected App) ;
- l'existence et l'activation du Prompt Template et de ses prérequis (Einstein Generative AI) ;
- le permission set du composant (accès Apex, Named Credential, Prompt Template) ;
- un test d'appel à la Metadata API en lecture seule.

Chaque contrôle affiche vert/rouge et l'action à faire.

### 5.5 Livraison

- Unlocked package, installé par l'admin.
- Composant exposé dans une page d'application (App Page) et un onglet.
- Permission set `Metadata_Quality_Audit_Admin`.

## 6. Structure du dépôt

```
.
├── README.md             # présente les deux flux
├── skill/                # SKILL.md + references/ (déplacés depuis la racine)
├── admin-app/                  # projet SFDX : LWC, Apex, Prompt Template, perm set, Named Credential
└── docs/superpowers/specs/
```

## 7. Laissé au développeur

- Taille des lots du Prompt Template et gestion des erreurs du modèle.
- Mise en forme exacte du composant (SLDS).
- Gestion de la limite de temps Apex sur les gros objets (plus de 100 champs).
- Choix entre `updateMetadata` et `deploy` (zip) pour l'écriture, selon ce que la Named Credential et les limites Apex permettent ; les deux passent par la Metadata API.
- Stratégie de tests Apex (appels HTTP et LLM simulés).
- Vérifier la lecture de `EntityDefinition.Description` en SOQL standard.

## 7bis. Décisions complémentaires (choix de Claude, à relire)

- **Phase 0 bloquante.** Avant tout le reste, un spike valide depuis Apex : Named Credential en boucle, `updateMetadata` sur un champ custom puis sur un champ standard. Si cela échoue, repli sur l'approche C dégradée (le composant génère le XML à déployer, l'admin l'applique) et le design est rouvert.
- **Exécution.** L'analyse est pilotée par le LWC, qui appelle Apex par lots de champs et affiche une progression. Pas de Queueable en v1. Cas nominal : objet jusqu'à environ 300 champs, échantillon de 100.
- **Masquage.** Fait en Apex avant tout appel au modèle : types email, téléphone, chiffré et noms de champ sensibles masqués (2 caractères + `***`), autres valeurs tronquées à 60 caractères. Le Prompt Template est de type Flex, avec entrées texte/JSON ; le modèle est celui par défaut de l'org.
- **Règles partagées.** Duplication contrôlée : `skill/SKILL.md` reste la référence, et le README du flux `admin-app/` renvoie aux règles ; toute évolution se fait dans les deux flux.
- **Langue.** Langue de référence = `Organization.LanguageLocaleKey`, comparée à la langue de l'utilisateur connecté. La comparaison s'applique même si Translation Workbench est désactivé.
- **Test.** Org de développement ou sandbox avec Einstein Generative AI ; recette manuelle en v1, sans jeu de référence automatisé.
- **Package.** Unlocked package sans namespace.

**Décision de l'utilisateur :**
- **Identité d'écriture : par utilisateur.** L'External Credential utilise un principal par utilisateur : chaque admin s'authentifie une fois (OAuth), les écritures se font avec ses droits et l'audit lui est attribué. Aucun secret n'est livré dans le package ; la Connected App / External Client App est créée dans l'org avec l'aide de l'assistant de configuration (§5.4). Le permission set donne accès au composant et à l'External Credential, pas des droits d'écriture propres.

## 8. Risques

- Prérequis d'org (Einstein Generative AI, Prompt Builder) absents : le composant doit le dire clairement et ne pas échouer en silence.
- Écriture de descriptions sur des champs standard : persistance confirmée sur `Account.Industry` seulement ; la relecture après application reste obligatoire.
- La Named Credential en boucle demande une configuration unique par org : c'est le coût de l'approche A.

## 9. Décision du 2026-11-19 : écriture par OAuth (approche A confirmée)

Deux voies ont été testées avec succès depuis Apex sur `org-de-test` :
- **A — OAuth** : External Client App + Auth Provider (My Domain) + External Credential (principal par utilisateur) + Named Credential en boucle. Écriture validée sur un champ custom et sur `Account.Industry`.
- **Alternative — session Visualforce** (`$Api.Session_ID` via une page, sans OAuth) : validée depuis un LWC, mais contournement non officiel et dépendant des réglages de session.

**L'utilisateur retient A (OAuth)** : voie officielle, identité par utilisateur, sans dépendre d'un contournement. L'alternative Visualforce est écartée ; elle reste un repli possible si la configuration OAuth se révèle trop lourde pour les admins.

Points à retenir pour l'implémentation :
- L'Auth Provider doit avoir ses *Authorize* et *Token Endpoint URL* sur le My Domain de l'org, sinon `invalid_client_id` (une ECA locale est inconnue de `login.salesforce.com`).
- Sur un champ **custom**, `updateMetadata` remplace la définition entière : relire la définition complète (`readMetadata`) puis la renvoyer modifiée. Sur un champ **standard**, `fullName` + `description` suffisent.
- Le jeton se passe par `{!$Credential.OAuthToken}` dans l'en-tête SOAP (Named Credential avec « Allow Formulas in HTTP Body »).
- L'assistant de configuration (§5.4) doit guider : ECA (callback `…/services/authcallback/<suffixe>`, scopes `api refresh_token`, flux code d'autorisation), Auth Provider (URLs My Domain), authentification de l'utilisateur sur l'External Credential, assignation du permission set.
