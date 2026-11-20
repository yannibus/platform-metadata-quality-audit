#!/usr/bin/env bash
# Configuration propre à une org : External Client App, External Credential, Named Credential.
# Usage : ./setup.sh <alias-de-l-org>
# Prérequis : Salesforce CLI (sf), jq, et que le package (ou admin-app/force-app) soit déjà déployé.
set -euo pipefail

ORG="${1:?Usage: ./setup.sh <alias-de-l-org>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

INFO="$(sf org display --target-org "$ORG" --json 2>/dev/null || true)"
DOMAIN="$(jq -r '.result.instanceUrl // empty' <<<"$INFO")"
USERNAME="$(jq -r '.result.username // empty' <<<"$INFO")"
[ -n "$DOMAIN" ] || { echo "Org introuvable ou non authentifiée : $ORG" >&2; exit 1; }
echo "Org : $ORG ($DOMAIN)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo '{"packageDirectories":[{"path":"force-app","default":true}],"sourceApiVersion":"68.0"}' > "$WORK/sfdx-project.json"

stage() { # $1 = dossier du modèle ; copie dans $WORK/<nom> avec les valeurs de l'org substituées
  mkdir -p "$WORK/$1" && cp -R "$HERE/template/$1/." "$WORK/$1/" && cp "$WORK/sfdx-project.json" "$WORK/$1/"
  find "$WORK/$1" -type f -name '*.xml' \
    -exec sed -i.bak -e "s#__MY_DOMAIN__#$DOMAIN#g" -e "s#__CONTACT_EMAIL__#$USERNAME#g" {} \; -exec rm -f {}.bak \;
}

deploy() { # $1 = dossier préparé ; affiche les erreurs de déploiement au lieu de les masquer
  local out
  out="$(cd "$WORK/$1" && sf project deploy start --source-dir force-app --target-org "$ORG" --json 2>&1 || true)"
  if [ "$(jq -r '.result.success // false' <<<"$out" 2>/dev/null || echo false)" != "true" ]; then
    echo "Échec du déploiement ($1) :" >&2
    jq -r '(.result.details.componentFailures // [])[] | "  - \(.fullName): \(.problem)"' <<<"$out" 2>/dev/null >&2 || echo "$out" >&2
    jq -r '.message // empty' <<<"$out" 2>/dev/null >&2 || true
    exit 1
  fi
}

echo; echo "1/3  Déploiement de l'External Client App…"
stage eca
deploy eca

# La clé est générée par l'org : on réessaie quelques secondes, sans jamais interrompre le script si elle reste introuvable.
KEY=""
for _ in 1 2 3; do
  KEY_DIR="$(mktemp -d)"
  cp "$WORK/sfdx-project.json" "$KEY_DIR/" && mkdir -p "$KEY_DIR/force-app"
  (cd "$KEY_DIR" && sf project retrieve start --metadata ExtlClntAppGlobalOauthSettings:Metadata_Audit_Self_glbloauth --target-org "$ORG" >/dev/null 2>&1) || true
  KEY="$(grep -ho '<consumerKey>[^<]*' "$KEY_DIR"/force-app/main/default/extlClntAppGlobalOauthSets/*.xml 2>/dev/null | sed 's/<consumerKey>//' | head -n1 || true)"
  rm -rf "$KEY_DIR"
  [ -n "$KEY" ] && break
  sleep 5
done
KEY_TXT="${KEY:-a lire dans l interface}"

cat <<TXT

2/3  À faire dans Setup (une seule fois, 2 minutes) :

  a) Setup → App Manager → « Metadata Audit Self » (External Client App) → Settings → OAuth Settings
     → « Consumer Key and Secret » : copiez la clé et le secret.
     (cle attendue : $KEY_TXT)

  b) Setup → Auth Providers → New → type « Salesforce » :
       Name et URL Suffix      : Metadata_Audit_Self
       Consumer Key / Secret   : ceux de l'étape a)
       Authorize Endpoint URL  : /services/oauth2/authorize
       Token Endpoint URL      : $DOMAIN/services/oauth2/token
       Default Scopes          : api refresh_token
       Use PKCE Extension      : cochée (l'app l'exige)

TXT
read -r -p "Auth Provider créé ? Appuyez sur Entrée pour continuer… " _

echo; echo "3/3  Déploiement de l'External Credential, de la Named Credential et du permission set…"
stage credentials
deploy credentials

cat <<TXT

Terminé. Reste, pour chaque administrateur :
  1. Assigner les permission sets « Metadata Quality Audit Admin » et « Metadata Quality Audit Credential ».
  2. Avatar → Paramètres → Authentication Settings for External Systems → New
     → External Credential « Metadata Audit Self » → Authentifier (une seule fois).
  3. Ouvrir l'onglet « Audit métadonnées » : l'écran de configuration doit être vert.
TXT
