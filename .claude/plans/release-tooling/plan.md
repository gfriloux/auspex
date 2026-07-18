# Plan : outillage release (premier tag v0.3.0)

**Type :** infra (nix / ci / doc) + bump de version
**Objectif :** monter l'outillage de release que la convention du dépôt lie au **premier
tag** — git-cliff + CHANGELOG, CI GitHub Actions, workflow de release déclenché par tag,
renovate — puis aligner `plugin.json` sur `0.3.0`. À l'issue, **l'utilisateur** pose et push
le tag `v0.3.0`, ce qui déclenche la première release.
**Pourquoi :** `CLAUDE.md`/`README.md` : « Outillage release (renovate, git-cliff, workflow
release) : ajouté au **premier tag**, pas avant. » On y est. Aujourd'hui : aucun `.github/`,
pas de changelog, `plugin.json` bloqué à `0.1.0`.
**Étage(s) :** `nix` (flake devShell), `ci` (workflows), `doc`, `chore` (version). **Aucun
changement `query`/`model`/`view` ; aucun golden touché.**

## Décisions techniques (validées avec l'utilisateur)

1. **Périmètre complet** : git-cliff + CHANGELOG, workflow release, **CI GitHub Actions**
   (inexistante aujourd'hui), et renovate.
2. **Déclenchement des releases : tag manuel → release auto.** L'utilisateur pose/push
   `vX.Y.Z` (politique git hybride : Claude ne tag jamais). Le workflow `release.yml` réagit
   au tag : génère les notes via git-cliff et crée la release GitHub. Pas de bot qui tag.
3. **CI = une seule définition de portes.** Le workflow CI appelle `nix develop --command
   just ci` — mêmes portes que pre-commit et le dev local. On ne duplique pas les commandes.
4. **Nix dans les runners** : `DeterminateSystems/nix-installer-action` (flakes activés,
   substituer depuis `cache.nixos.org` où quickshell/qt6 sont prébuild). Cache inter-run
   FlakeHub optionnel, non bloquant pour v1 (flag dans manual_tests).
5. **git-cliff** ajouté au **dev shell** (flake) + cible `just changelog` → « une seule
   définition » : le workflow release et le local produisent le même changelog.
6. **Versioning** : `plugin.json.version` suit le tag (SemVer). Bump manuel à `0.3.0` dans ce
   plan ; le process de release (README) rappellera de bumper avant de tagger.

## Périmètre

**In scope :** `cliff.toml`, `CHANGELOG.md` (initial, v0.1.0→v0.3.0), `.github/workflows/
ci.yml`, `.github/workflows/release.yml`, `renovate.json`, ajout git-cliff au flake + cible
`just changelog`, bump `plugin.json` → `0.3.0`, doc du process de release.

**Out of scope :** poser/pusher le tag (utilisateur), signature de commits/tags, publication
sur un registre de plugins DMS (pas de registre), build d'artefacts (le plugin est du source
QML installé via home-manager — la release GitHub = notes + source), changement fonctionnel.

## Fichiers touchés

- [ ] `plugin.json` — version `0.1.0` → `0.3.0`.
- [ ] `cliff.toml` *(nouveau)* — config git-cliff (groupes par type Conventional Commits).
- [ ] `CHANGELOG.md` *(nouveau)* — généré, relu.
- [ ] `flake.nix` — `git-cliff` dans `devShells.default.packages`.
- [ ] `Justfile` — cible `changelog` (git-cliff).
- [ ] `.github/workflows/ci.yml` *(nouveau)* — `just ci` sur push/PR.
- [ ] `.github/workflows/release.yml` *(nouveau)* — tag `v*` → notes git-cliff + release GH.
- [ ] `renovate.json` *(nouveau)* — inputs flake Nix + github-actions.
- [ ] `README.md` / `CLAUDE.md` — process de release + « outillage en place ».

## Étapes atomiques (chacune = 1 commit)

### Étape 1 : Aligner la version du plugin
**Description :** `plugin.json` version `0.1.0` → `0.3.0` (SemVer, = futur tag).
**Vérification :** `just ci` ; `jq . plugin.json` valide.
**Commit :** `chore: aligner plugin.json sur la version 0.3.0`

### Étape 2 : git-cliff + CHANGELOG + cible just
**Description :** ajouter `git-cliff` au `devShells.default` du flake ; `cliff.toml`
(en-tête, groupes : Features/Fixes/Refactor/Docs/CI/Chore d'après le type Conventional
Commits, liens de comparaison GitHub) ; cible `just changelog` (`git-cliff -o CHANGELOG.md`) ;
générer `CHANGELOG.md` couvrant `v0.1.0`→`v0.3.0` (relire le rendu). Comme il n'existe pas
encore de tags, git-cliff regroupe l'historique sous « unreleased » ou via `--tag v0.3.0`
pour dater la première version — on génère avec `--tag v0.3.0`.
**Vérification :** `nix develop --command just changelog` produit un `CHANGELOG.md` cohérent ;
`just ci` (inchangé) vert.
**Commit :** `chore: git-cliff (cliff.toml) + CHANGELOG initial`

### Étape 3 : CI GitHub Actions
**Description :** `.github/workflows/ci.yml` — sur `push` (branches) et `pull_request` :
checkout, `DeterminateSystems/nix-installer-action`, puis `nix develop --command just ci`.
Un seul job Linux (x86_64). Concurrence : annuler les runs obsolètes par ref.
**Vérification :** `actionlint` si dispo, sinon relecture ; le vrai run se voit après push
(consigné dans manual_tests, non exécutable localement).
**Commit :** `ci: workflow d'intégration (just ci sur push/PR)`

### Étape 4 : Workflow de release (tag → release GitHub)
**Description :** `.github/workflows/release.yml` — `on: push: tags: ['v*']` : checkout
(fetch-depth 0), génère les notes du tag via `orhun/git-cliff-action` (`--latest`), crée la
release avec `softprops/action-gh-release` (body = notes, `GITHUB_TOKEN`, `permissions:
contents: write`). Pas d'artefact (source-only).
**Vérification :** relecture ; validation réelle au 1er tag poussé par l'utilisateur
(manual_tests).
**Commit :** `ci: workflow de release déclenché par tag`

### Étape 5 : renovate
**Description :** `renovate.json` — preset de base, manager **nix** (inputs du flake) +
**github-actions** (versions d'actions), regroupement raisonnable, labels. (L'app Renovate
GitHub doit être activée côté dépôt — noté dans manual_tests, hors code.)
**Vérification :** `jq . renovate.json` ; schéma renovate respecté (relecture).
**Commit :** `chore: configuration renovate (inputs flake + actions)`

### Étape 6 : Doc du process de release
**Description :** section README « Release » : bumper `plugin.json`, mettre à jour le
changelog (`just changelog`), commit, **l'utilisateur** tag `vX.Y.Z` + push → le workflow
publie. Mettre à jour la note « outillage au premier tag » (désormais en place) dans
`CLAUDE.md`/`README.md`.
**Vérification :** relecture ; `just ci`.
**Commit :** `docs: documenter le process de release`

## Portes de qualité (clôture)

- [ ] `just ci` vert (fmt-check + lint + test), goldens **inchangés**.
- [ ] `just changelog` régénère un `CHANGELOG.md` propre et déterministe.
- [ ] Workflows relus (syntaxe Actions), validés en vrai au 1er push/tag (manual_tests).
- [ ] `plugin.json` = `0.3.0`.
- [ ] Commits atomiques sur `chore/release-tooling` ; **l'utilisateur** relit, merge, **puis
      tag `v0.3.0` + push** (déclenche la release). Claude ne tag/merge/push jamais.
