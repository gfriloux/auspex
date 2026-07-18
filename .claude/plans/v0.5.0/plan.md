# Plan : v0.5.0 — quick-links web (délégation sortante)

**Type :** modèle (2 champs + golden) + helpers `format.js` (purs) + vue + nix + doc
**Objectif :** au survol d'une ligne de problème, proposer des **liens sortants** vers le
frontend web Zabbix : **ouvrir le problème** et **ouvrir la page du host**. Non-mutant
(ouvre un onglet, n'écrit rien dans Zabbix). URLs par **templates configurables** (défauts
recherchés), base dérivée de l'URL d'API.
**Pourquoi :** premier lot des quick-links du DESIGN, limité à ce qui est faisable proprement
aujourd'hui. **SSH** (résolution d'adresse/terminal non résolue) et **graphe** (nécessite des
appels API supplémentaires + choix de « quel » graphe) restent **hors périmètre**.
**Étage(s) :** `model` (problems.js + goldens), `model`/`format.js` (URL, purs), `view`
(Settings.qml, Cockpit.qml, AuspexWidget.qml), `nix` (hm-module), `doc`. **Lecture seule
préservée** (délégation sortante uniquement).

## Décisions techniques

1. **Templates d'URL configurables** (StringSetting), défauts issus de la vérif web Zabbix 7.0 :
   - problème : `{base}/tr_events.php?triggerid={triggerid}&eventid={eventid}`
   - host : `{base}/zabbix.php?action=problem.view&hostids[]={hostid}`
   Un template **vide désactive** son icône (pas de toggle séparé). Robuste aux variations
   d'instance/version : l'utilisateur ajuste sans toucher au code (invariant *agnostique à
   l'instance*).
2. **`{base}` dérivé de l'URL d'API** : on retire `/api_jsonrpc.php` (et le `/` final).
   Helper pur `frontendBase(apiUrl)`.
3. **Substitution de template** : helper pur `buildFrontendUrl(template, fields)` remplace
   `{base}`, `{hostid}`, `{triggerid}`, `{eventid}` ; retourne `""` si template vide ou
   champ requis manquant (→ icône masquée).
4. **Ouverture** : `Qt.openUrlExternally(url)` (idiomatique DMS). Backend `xdg-open`
   (xdg-utils) ajouté en dep runtime.
5. **Données** : le modèle porte désormais `triggerid` et `hostid` (déjà dans l'API/fixtures,
   simplement jetés aujourd'hui). Changement déterministe → **golden**.
6. **Layering** : le model fournit les identifiants ; la vue construit l'URL (helper pur) et
   ouvre (effet de bord). Le service n'est pas touché.

## Périmètre

**In scope :** `triggerid`+`hostid` au modèle, helpers d'URL, réglages templates, 2 quick-links
au survol (problème, host), dep xdg-utils, doc.

**Out of scope :** SSH host, lien graphe, toute écriture Zabbix (ack/close), encodage exotique
d'URL (ids numériques → sûrs).

## Fichiers touchés

- [ ] `src/model/problems.js` — `parseTriggers` garde `hostid` ; `joinProblems` ajoute
      `triggerid` + `hostid`.
- [ ] `tests/golden/problems-*.json` — régénérés (`just bless`), relus.
- [ ] `tests/tst_model.qml` — MAJ `test_parseTriggers_*` / `test_joinProblems_*` + tests des
      helpers d'URL.
- [ ] `src/model/format.js` — `frontendBase(apiUrl)` + `buildFrontendUrl(template, fields)` (purs).
- [ ] `src/view/Settings.qml` — 2 `StringSetting` (templates problème + host).
- [ ] `src/view/AuspexWidget.qml` — cfg readers + `frontendBase`.
- [ ] `src/view/Cockpit.qml` — rangée de quick-links au survol du delegate.
- [ ] `nix/hm-module.nix` + `plugin.json` — `xdg-utils` / `requires`.
- [ ] `README.md` / `DESIGN.md` — quick-links web livrés, SSH/graphe hors périmètre.

## Étapes atomiques (chacune = 1 commit)

### Étape 1 : Modèle — exposer `triggerid` et `hostid`
**Description :** `parseTriggers` : `map[triggerid] = { name, hostid }` (host absent →
`{name:"", hostid:""}`). `joinProblems` : `host = map[tid].name`, + `triggerid: p.triggerid`,
+ `hostid: map[tid] ? map[tid].hostid : ""`. MAJ des tests inline concernés. `just bless`,
**relire le diff des goldens** (chaque objet gagne `triggerid`+`hostid` ; l'orphelin →
hostid `""`).
**Vérification :** `just ci` ; diff golden intentionnel et minimal.
**Commit :** `feat(model): exposer triggerid et hostid dans le modèle`

### Étape 2 : Helpers d'URL frontend (purs, testés inline)
**Description :** `format.js` : `frontendBase(apiUrl)` (retire `/api_jsonrpc.php` + `/` final) ;
`buildFrontendUrl(template, fields)` (substitue `{base}{hostid}{triggerid}{eventid}`, `""` si
template vide ou placeholder requis absent). Tests inline (dont host manquant → `""`).
**Vérification :** `just ci`.
**Commit :** `feat(model): helpers d'URL frontend (base + templates)`

### Étape 3 : Réglages — templates d'URL
**Description :** `Settings.qml` : `StringSetting` `frontendProblemUrl` et `frontendHostUrl`
avec les défauts (§Décisions), descriptions mentionnant les placeholders et « vide = désactivé ».
`AuspexWidget` : `cfgFrontendProblemUrl`, `cfgFrontendHostUrl` (readonly, défauts = templates),
`frontendBase: Format.frontendBase(cfgUrl)`.
**Vérification :** `just ci` ; réglages visibles/persistants (manuel).
**Commit :** `feat(view): réglages templates d'URL frontend`

### Étape 4 : Quick-links au survol (problème, host)
**Description :** `Cockpit.qml` delegate : rangée d'icônes ancrée à droite, **fondu au survol**
(`rowHover.hovered`), fond léger pour lisibilité. `open_in_new` → URL problème ; icône host
(`dns` ou `lan`) → URL host. Chaque icône construit son URL via `Format.buildFrontendUrl(...)`
(base + ids de `modelData`) et **n'apparaît que si l'URL est non vide** ; clic →
`Qt.openUrlExternally(url)`. Non-mutant.
**Vérification :** `just ci` ; manuel : survol → icônes, clic → onglet navigateur sur la bonne
page ; template vidé → icône absente.
**Commit :** `feat(view): quick-links web au survol (problème, host)`

### Étape 5 : Dépendance xdg-open (nix + manifest)
**Description :** `hm-module.nix` : `pkgs.xdg-utils` dans `home.packages`. `plugin.json` :
`requires` += `"xdg-open"`.
**Vérification :** `just ci` ; `alejandra --check` ; `jq` valide.
**Commit :** `feat(nix): dépendance xdg-open (xdg-utils) au runtime`

### Étape 6 : Doc
**Description :** README (quick-links web livrés, templates configurables), DESIGN (note
d'implémentation : problème + host seulement, SSH/graphe reportés, `Qt.openUrlExternally`,
base dérivée). Commentaires d'en-tête si utile.
**Vérification :** relecture ; `just ci`.
**Commit :** `docs: quick-links web (v0.5.0)`

### Étape 7 : Préparer la release
**Description :** `plugin.json.version` → `0.5.0` ; `just changelog` (`--tag v0.5.0`), relire.
**Vérification :** `jq`, `just ci`, changelog cohérent.
**Commit :** `chore: préparer la release v0.5.0 (version + changelog)`

## Portes de qualité (clôture)

- [ ] `just ci` vert ; **goldens régénérés intentionnellement** (diff = ajout de `triggerid`
      + `hostid`, rien d'autre).
- [ ] `manual_tests.md` exécuté : survol/clic problème + host, template vide = icône absente,
      base dérivée correcte. **Formats d'URL à re-confirmer sur la vraie prod** (défauts
      recherchés, ajustables sans code).
- [ ] Doc synchronisée ; commits atomiques sur `feat/v0.5.0-quicklinks`.
- [ ] **L'utilisateur** relit, merge, tag `v0.5.0`.
