# Tests manuels — v0.1.0 (couche données)

v0.1.0 est **pur et golden-testé** : l'essentiel de la validation est automatique
(`just test`). Il n'y a **ni UI, ni HTTP réel** à cette étape — ces tests-là arrivent en
v0.2.0. Cette liste couvre donc surtout le socle et la cohérence des goldens.

## Socle

- [ ] `nix develop` entre dans le dev shell sans erreur (quickshell, qmllint/qmlformat/qmltestrunner présents).
- [ ] `just ci` passe (fmt-check + lint + test) au vert.
- [ ] `just bless` régénère les goldens ; `git diff` sur `tests/golden/` est **vide** si rien n'a changé.

## Couche données (revue humaine du diff)

- [ ] Modifier un transform à la main, `just test` **échoue** (le harnais détecte bien la régression).
- [ ] `just bless` après un changement intentionnel produit un diff **lisible et attendu**.
- [ ] Aucun token / secret présent dans `tests/fixtures/` ni `tests/golden/` (`git grep -i` de contrôle).

## Reporté à v0.2.0 (hors périmètre ici)

- Requête HTTP réelle vers une instance Zabbix 7.0 (auth Bearer, utilisateur read-only).
- Rendu du badge / cockpit, états vide/erreur/chargement.
- Notification desktop à l'apparition d'un nouveau problème (delta réel).
- Lancement Quickshell sur Wayland, installation via home-manager.
