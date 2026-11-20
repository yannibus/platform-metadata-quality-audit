# Audit qualité des métadonnées — composant pour administrateurs

Un composant Lightning à installer dans votre org pour **auditer et améliorer les descriptions, textes d'aide et libellés des champs** d'un objet, sans ligne de commande.

1. Choisissez un objet et le nombre d'enregistrements d'échantillon (1 à 100).
2. Le composant analyse les champs par lots et propose des textes (Prompt Template, Einstein Generative AI).
3. Relisez, corrigez le texte proposé, cochez ou décochez chaque ligne.
4. Cliquez sur **Appliquer** : les changements sont écrits dans l'org puis relus pour vérification.

Pourquoi c'est utile : des descriptions précises aident aussi les recherches de **Agentforce Coworker** et des agents à choisir le bon champ (voir « Bonnes pratiques » plus bas).

## Périmètre de la v1

- **Champs** standard et custom : `description`, texte d'aide (`inlineHelpText`) ; libellé pour les champs **custom** uniquement.
- Le **taux de remplissage** affiché est calculé sur les 2 000 enregistrements les plus récents de l'objet (une analyse sur tout l'objet dépasserait les limites Salesforce sur les gros volumes).
- Les champs de packages gérés sont listés mais jamais modifiés. Aucun libellé standard n'est proposé.
- **Hors périmètre** : descriptions et libellés de l'objet lui-même (v1.1), traductions (utiliser l'agent `sf-metadata-translator`), plusieurs objets en une seule analyse.

## Prérequis

- Einstein Generative AI activé (Prompt Builder).
- Un utilisateur dont la **langue est celle de l'org** : sinon `describe` renvoie des traductions et les réécrire écraserait les textes de référence. L'application est alors bloquée, l'analyse reste possible.
- Pour auditer **tous** les champs : un profil avec « View All Fields » (les champs non visibles sont signalés).

## Installation

1. Déployer le contenu de `force-app/` (composant, Apex, Prompt Template, permission set, onglet). Pas de package à installer : le code source se déploie directement.
   ```bash
   cd admin-app
   sf project deploy start --source-dir force-app --target-org <alias-de-l-org>
   ```
2. Lancer la configuration propre à l'org (External Client App, External Credential, Named Credential) :
   ```bash
   cd setup && ./setup.sh <alias-de-l-org>
   ```
   Le script déploie l'app OAuth, vous guide pour créer l'**Auth Provider** (clé et secret à copier depuis l'interface, avec « Use PKCE Extension » cochée — le secret n'est jamais dans le dépôt), puis déploie les credentials.
3. Assigner les permission sets **Metadata Quality Audit Admin** et **Metadata Quality Audit Credential** aux administrateurs.
4. Chaque administrateur s'authentifie une fois : avatar → Paramètres → *Authentication Settings for External Systems* → New → `Metadata Audit Self` → Authentifier.
5. Ouvrir l'onglet **Audit métadonnées** : l'écran de configuration indique ce qui reste à faire, avec l'action pour chaque point.

### Pourquoi cette configuration ?

Apex ne sait pas écrire les descriptions de champs ; seule la Metadata API le permet, et elle exige un jeton OAuth. L'org s'appelle donc elle-même comme une application externe, **avec l'identité de chaque administrateur** (les écritures respectent ses droits et son nom figure dans l'audit).

## Sécurité et garde-fous

- Rien n'est écrit sans clic sur **Appliquer**.
- Les valeurs sensibles de l'échantillon (e-mail, téléphone, IBAN, etc.) sont masquées avant tout envoi au modèle ; les autres sont tronquées à 60 caractères.
- L'échantillon (1 à 100 enregistrements) et le taux de renseignement (les 2000 derniers) portent sur les enregistrements **les plus récemment mis à jour**, du plus récent au plus ancien.
- Limites respectées : description 1000 caractères, aide 510, libellé de champ 40.
- Après écriture, chaque valeur est **relue** et marquée « Vérifié » ou « Non vérifié ».

## Aide aux recherches d'Agentforce Coworker

Coworker retrouve les champs custom et leurs relations grâce à leurs descriptions. Le composant écrit donc ses propositions pour cet usage :
- les champs de **relation** et d'**ID externe** disent à quoi ils servent et **avec quel objet ils servent de clé de jointure** ;
- les champs **jumeaux** (par exemple `Industry` standard et `Industry__c` custom, repérés par le même libellé ou le même nom de base) citent leur jumeau et disent lequel utiliser. Si la différence ne se déduit pas des données, la description le dit (« à ne pas confondre avec… ») au lieu d'inventer une règle.

Relisez ces propositions en priorité : le modèle ne voit que les libellés, types, descriptions et taux de remplissage.

## Développement

```bash
npm install            # outillage de test
npm run test:unit      # tests Jest du composant
sf apex run test --class-names MetadataReaderTest --target-org <alias> --synchronous
```
Les tests Jest ne sont pas déployés (`.forceignore`).
