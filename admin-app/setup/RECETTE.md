# Recette — à faire sur une org vierge (avec Einstein Generative AI)

Statut au 2026-11-20 : **exécutée sur une org vierge** (Enterprise, en_US, trial) avec déploiement du code source (pas de package). Tout est validé sauf le dernier point de la liste (lot invalide du modèle), couvert seulement par les tests unitaires.

Défauts trouvés pendant la recette et corrigés : `setup.sh` jugeait un déploiement réussi comme échoué quand le CLI écrit des avertissements sur stderr ; l'Authorize Endpoint URL de l'Auth Provider doit être l'URL complète du My Domain.

- [x] Déployer `force-app/` : succès, tests Apex verts. — OK : 57 tests Apex verts sur l'org vierge
- [x] `./setup/setup.sh <alias>` : l'app se déploie, la clé est affichée, le déploiement final réussit. — OK : ECA déployée, clé affichée, déploiement final réussi (après correction du script)
- [x] Créer l'Auth Provider avec les URL du My Domain (sinon `invalid_client_id`). — OK : créé à la main avec les URL du My Domain
- [x] Assigner les deux permission sets ; s'authentifier sur l'External Credential. — OK : 4 contrôles verts (vérifiés par SetupChecker)
- [x] Onglet « Audit métadonnées » : écran de configuration vert (4 contrôles). — OK : écran de configuration masqué car tout est vert
- [x] Analyser un objet standard (Account, échantillon 5) et un objet custom : propositions pertinentes, champs non visibles signalés. — OK : Account (226 propositions, 150 premiers champs, avertissement affiché) et Opportunity (150 propositions)
- [x] **Appliquer** dans l'interface : au moins un champ standard et un champ custom avec liste de valeurs ; relecture « Vérifié » ; valeurs de la liste intactes. — OK : custom picklist (7 valeurs, jeu identique avant/après), picklists standard LeadSource (10 valeurs) et StageName intacts, relecture « Vérifié »
- [x] Utilisateur en langue différente de l'org : application bloquée, analyse possible. — OK : fr contre en_US : LanguageGuard.ok = false, application bloquée ; langue restaurée
- [x] Texte contenant `& < > '` appliqué et relu à l'identique. — OK : relu à l'identique
- [ ] Lot invalide du modèle : avertissement, les autres lots continuent.
- [x] Objet de plus de 150 champs : avertissement de troncature. — OK : Account (278 champs) : avertissement de troncature affiché
