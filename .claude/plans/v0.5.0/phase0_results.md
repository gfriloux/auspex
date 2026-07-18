# Phase 0 — Audit avant v0.5.0 (quick-links web)

**Date :** 2026-07-18
**Branche :** `feat/v0.5.0-quicklinks` (depuis `main`, v0.4.0 publié)

## `nix develop --command just ci`

- **exit 0.** fmt-check ✅ · lint ✅ · test **27 passed, 0 failed**.

## Constats (point de départ)

- **`triggerid` et `hostid` sont disponibles mais jetés** avant le modèle final :
  - `parseProblems` garde `triggerid` (= `objectid`), mais `joinProblems` ne le recopie pas.
  - `trigger.get` demande déjà `selectHosts: ["hostid", "name"]` et **les fixtures contiennent
    déjà `hostid`** (ex. `{"hostid":"10103","name":"db01"}`), mais `parseTriggers` ne garde que
    `name`. → **aucune fixture à modifier** ; seuls le model et les goldens changent.
- Les cas golden sont pilotés par `tests/cases.js` (`joinCase` = parseProblems + parseTriggers
  + joinProblems). Ajouter des champs au modèle → **goldens régénérés par `just bless`**, à relire.
- **Ouverture d'URL** : DMS utilise `Qt.openUrlExternally(url)` (idiomatique Qt). Backend Linux
  = `xdg-open` (xdg-utils) → à ajouter en dep runtime par sécurité.
- **URLs frontend Zabbix 7.0 confirmées par recherche web** (cf. plan §Décisions) :
  - problème/événement : `…/tr_events.php?triggerid=<triggerid>&eventid=<eventid>` (toujours
    présent dans les sources 7.0) ;
  - host : `…/zabbix.php?action=problem.view&hostids[]=<hostid>` (paramètre de page documenté
    7.0 ; la forme interactive `filter_hostids[]&filter_set=1` coexiste → **templates
    configurables** pour absorber la nuance).

## Conclusion

v0.5.0 touche `model` (2 champs + goldens), `model`/`format.js` (helpers d'URL purs, testés
inline), `view` (Settings + quick-links au survol dans Cockpit), `nix` (xdg-utils), `doc`.
SSH et graphe restent **hors périmètre** (pas de solution propre).
