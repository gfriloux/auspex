# Tests manuels — outillage release

`just ci` reste la porte déterministe (fmt/lint/test). L'outillage release touche du CI et
des services GitHub : **non exécutable dans le dev shell**, à valider après push / au 1er tag.

## Local (dev shell)

- [ ] `nix develop --command just changelog` régénère `CHANGELOG.md` sans erreur ; le rendu
      regroupe bien les commits par type (Features / Fixes / Docs / …) et date v0.3.0.
- [ ] `git-cliff` est bien dans le PATH du dev shell.
- [ ] `jq . plugin.json` et `jq . renovate.json` valident (JSON bien formé).
- [ ] `plugin.json` affiche `"version": "0.3.0"`.
- [ ] `just ci` toujours vert.

## CI GitHub Actions (après push de la branche / PR)

- [ ] Le workflow **ci.yml** se déclenche sur la PR, installe Nix et exécute `just ci` au
      vert. Durée raisonnable (téléchargements depuis cache.nixos.org ; quickshell/qt6
      prébuild). Si trop lent : envisager un cache inter-run (FlakeHub / cachix) — non bloquant.
- [ ] Runs obsolètes annulés quand on push à nouveau (concurrence).

## Release (au 1er tag, posé par l'utilisateur)

Séquence attendue :

```bash
# après merge de la branche sur main
git checkout main && git pull
git tag -a v0.3.0 -m "v0.3.0 — cockpit direction C"
git push origin v0.3.0
```

- [ ] Le workflow **release.yml** se déclenche sur le tag `v0.3.0`.
- [ ] Une **release GitHub** `v0.3.0` est créée, avec des notes générées par git-cliff
      (mêmes groupes que le CHANGELOG local).
- [ ] Aucune écriture inattendue (pas d'artefact ; source-only).

## Renovate (service externe)

- [ ] L'app **Renovate** est activée sur `gfriloux/auspex` (côté GitHub, hors dépôt).
- [ ] Renovate ouvre son onboarding PR puis surveille les **inputs du flake** (nixpkgs,
      flake-parts) et les **versions d'actions** GitHub.

## Reporté / hors périmètre

- Pose et push du tag : **utilisateur** (jamais Claude).
- Signature GPG des commits/tags, publication sur un registre de plugins (inexistant).
