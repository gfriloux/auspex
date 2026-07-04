## Plan : v0.1.0 — couche données (query + model)

**Type :** requête + modèle/delta
**Objectif :** poser le socle déterministe d'auspex — construire les corps JSON-RPC
Zabbix 7.0, transformer les réponses en modèle de problèmes, calculer sévérité globale,
compteurs et **delta** (nouveaux / résolus) — le tout **pur et golden-testé, sans UI ni
réseau**.
**Pourquoi :** c'est le cœur testable sans serveur (cf. astropath : v0.1.0 = données,
v0.2.0 = UI/notifs). La forme du modèle gelée ici est ce qui alimentera ensuite le
**handoff design** (les champs réels affichés dans le cockpit).
**Étage(s) :** `nix` | `query` | `model` | `doc`

### Contexte & état du working tree

Dépôt quasi vide (commit initial + `DESIGN.md`, `CLAUDE.md`, `PROCEDURE_PLANS.md`). Aucun
toolchain, aucun `src/`, aucun test. La Phase 0 constatera l'absence de `just ci` : le
socle est justement la Phase 1.

### Périmètre

**In scope :**
- Dev shell Nix + `Justfile` (portes : `fmt-check`, `lint`, `test`, `ci`, `bless`) + `plugin.json`.
- Harnais de golden tests (fixtures API figées → modèle attendu).
- `query` : builders purs des corps JSON-RPC `problem.get` et `trigger.get(selectHosts)`.
- `model` : parsing, jointure problème←trigger→host, `worstSeverity`, `counts` par sévérité,
  `diffProblems` (delta), helpers `format` (ancienneté, libellé sévérité).

**Out of scope (v1 / plus tard) :**
- Toute UI QML, le service HTTP `Zabbix.qml`, les notifications desktop → **v0.2.0**.
- Le packaging home-manager → **v0.2.0**.
- Écriture (ack/close/commentaire), multi-instance, corrélation cause/symptôme,
  enrichissement graph → cap futur (cf. DESIGN.md).
- Outillage release (renovate, git-cliff) → premier tag.

### Décisions techniques

1. **Deux appels, une jointure.** `problem.get` renvoie `objectid` (= triggerid) mais pas
   le host. On récupère les problèmes, on collecte les triggerids, on appelle
   `trigger.get` avec `triggerids` + `selectHosts`, et le `model` joint. La couche `query`
   ne fait que **construire les corps** ; l'orchestration des deux appels (le 2e dépend du
   1er) sera au service `Zabbix.qml` en v0.2.0 — en v0.1.0 on teste chaque builder et la
   jointure sur réponses figées.
2. **Corps JSON-RPC purs, sans auth.** Chaque builder renvoie
   `{jsonrpc:"2.0", method, params, id}`. Aucun `auth` dans le corps (déprécié en 7.0),
   aucun token : l'auth Bearer est injectée par le service (v0.2.0). → fixtures/goldens
   committables sans secret.
3. **`problem.get` — params par défaut :** `{output:[...], selectAcknowledges:..., selectTags:...,
   recent:false, sortfield:["eventid"], sortorder:"DESC"}`. Filtre `severities` optionnel
   (injecté depuis la config plus tard). Le tri déterministe est requis pour des goldens stables.
4. **Modèle de domaine d'un problème :** `{ eventid, host, trigger, severity (0-5),
   severityLabel, since (clock), acknowledged, suppressed }`. Plus l'agrégat :
   `{ problems[], worstSeverity, counts{0..5} }`.
5. **Delta pur :** `diffProblems(prev, curr)` → `{ added[], resolved[] }` par `eventid`.
   Fonction pure de (état précédent, état courant) — c'est la base des notifications v0.2.0,
   testée ici sans notification réelle.
6. **Golden en JSON**, harnais calqué sur astropath (`tests/lib/golden.js`, runner Qt Quick
   Test). `just bless` régénère, on relit le diff.

### Fichiers touchés

- [ ] `flake.nix`, `flake.lock`, `Justfile`, `.gitignore`, `.pre-commit-config.yaml`, `plugin.json`
- [ ] `tests/lib/golden.js`, `tests/tst_*.qml`, `tests/cases.js`
- [ ] `src/query/queries.js`
- [ ] `src/model/problems.js`, `src/model/format.js`
- [ ] `tests/fixtures/<cas>/…`, `tests/golden/<cas>.json`
- [ ] `README.md` (données documentées), `DESIGN.md` (si un détail d'impl le précise)

### Étapes atomiques

#### Étape 1 : Scaffold Nix + Just + plugin.json
**Description :** `flake.nix` (dev shell : quickshell, Qt6 `qmllint`/`qmlformat`/`qmltestrunner`,
`just`, `jq`, `alejandra`, `deadnix`), `Justfile` (cibles `fmt`/`fmt-check`/`lint`/`test`/`ci`/`bless`),
`plugin.json` (manifest DMS, nom « Auspex »), `.gitignore` (`tmp/`, artefacts nix),
`.pre-commit-config.yaml` (appelle le Justfile).
**Vérification :** `nix develop --command just ci` s'exécute (vert, zéro test pour l'instant).
**Commit :** `chore(nix): scaffold dev shell, Justfile et manifest plugin`

#### Étape 2 : Harnais de golden tests (vide)
**Description :** `tests/lib/golden.js` (chargement fixture/golden, comparaison, mode bless),
runner Qt Quick Test, `tests/cases.js` (orchestration, zéro cas). `just test` et `just bless`
fonctionnels à vide.
**Vérification :** `just test` passe (0 cas), `just bless` no-op.
**Commit :** `test: harnais golden (fixtures API → modèle attendu)`

#### Étape 3 : `query` — builders JSON-RPC
**Description :** `src/query/queries.js` : `problemGet(opts)` et `triggerGetWithHosts(triggerids)`,
fonctions pures renvoyant le corps JSON-RPC (sans auth). Fixtures d'entrée (opts) + goldens
(corps attendu) pour : problem.get par défaut, problem.get filtré par `severities`,
trigger.get pour un set de triggerids.
**Vérification :** `just test` (nouveaux goldens verts).
**Commit :** `feat(query): builders problem.get et trigger.get`

#### Étape 4 : `model` — parsing & jointure problème→host
**Description :** `src/model/problems.js` : `parseProblems(res)`, `parseTriggers(res)` (map
triggerid→host), `joinProblems(...)` → modèle de domaine. `src/model/format.js` :
`relativeTime(clock)`, `severityLabel(n)`. Fixtures = réponses figées `problem.get` +
`trigger.get` ; goldens = liste de problèmes de domaine. Cas : vide, un problème,
multi-hosts, acquitté, supprimé.
**Vérification :** `just test`.
**Commit :** `feat(model): parsing et jointure problème→host`

#### Étape 5 : `model` — agrégats & delta
**Description :** `worstSeverity`, `counts` par sévérité (0–5), `diffProblems(prev, curr)`
→ `{added, resolved}`. Fixtures : deux états successifs ; goldens : agrégats + delta
(apparition, résolution, mixte, aucun changement).
**Vérification :** `just test`.
**Commit :** `feat(model): sévérité globale, compteurs et delta`

#### Étape 6 : Documentation de la couche données
**Description :** `README.md` (ce qu'est auspex, statut v0.1.0 = données, comment tester) ;
préciser dans `DESIGN.md` §Implémentation tout détail de nommage arrêté ici.
**Vérification :** relecture ; `just ci`.
**Commit :** `docs: documenter la couche données v0.1.0`

### Portes de qualité
- [ ] `just ci` passe (fmt-check + lint + test)
- [ ] Goldens à jour et intentionnels, **aucun secret** dans fixtures/goldens
- [ ] Doc synchronisée (même commit)
- [ ] Commits atomiques sur une branche dédiée (`feat/v0.1.0-data-layer`)
- [ ] Forme du modèle gelée → prête pour le handoff design
