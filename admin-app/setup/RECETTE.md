# Recette — à faire sur une org vierge (avec Einstein Generative AI)

Statut au 2026-11-19 : **non exécutée sur org vierge**. Validé jusqu'ici : tests Apex et Jest, parcours d'analyse réel sur `org-de-test`, validation (dry-run) du package sur une seconde org.

- [ ] Déployer `force-app/` : succès, tests Apex verts.
- [ ] `./setup/setup.sh <alias>` : l'app se déploie, la clé est affichée, le déploiement final réussit.
- [ ] Créer l'Auth Provider avec les URL du My Domain (sinon `invalid_client_id`).
- [ ] Assigner les deux permission sets ; s'authentifier sur l'External Credential.
- [ ] Onglet « Audit métadonnées » : écran de configuration vert (4 contrôles).
- [ ] Analyser un objet standard (Account, échantillon 5) et un objet custom : propositions pertinentes, champs non visibles signalés.
- [ ] **Appliquer** dans l'interface : au moins un champ standard et un champ custom avec liste de valeurs ; relecture « Vérifié » ; valeurs de la liste intactes.
- [ ] Utilisateur en langue différente de l'org : application bloquée, analyse possible.
- [ ] Texte contenant `& < > '` appliqué et relu à l'identique.
- [ ] Lot invalide du modèle : avertissement, les autres lots continuent.
- [ ] Objet de plus de 150 champs : avertissement de troncature.
