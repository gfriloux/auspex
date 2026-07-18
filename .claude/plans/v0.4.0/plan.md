# Plan : v0.4.0 — notifications

**Type :** vue (service delta + effets de bord) + helpers `format.js` (purs) + nix + doc
**Objectif :** prévenir localement à l'apparition d'un **nouveau** problème : une
**notification desktop** (via `notify-send` → daemon DMS) sur le delta `added`, et un **pulse**
du badge de barre. Réglages : activation + seuil de sévérité mini.
**Pourquoi :** dernier étage de la vision auspex (« un Nagstamon repensé »). Le modèle a déjà
`diffProblems` (delta pur, testé) ; il reste à le brancher côté service et à faire les effets
de bord côté vue. DESIGN §« Notification desktop » + §« Widget de barre (états) » (pulse).
**Étage(s) :** `view` (Zabbix.qml, AuspexWidget.qml, Settings.qml), `model` (format.js, purs),
`nix` (hm-module), `doc`. **Lecture seule préservée** : notifier est un effet sortant local,
aucune écriture Zabbix.

## Décisions techniques (validées avec l'utilisateur)

1. **Mécanisme = `notify-send` via `Quickshell.execDetached`** (voie idiomatique DMS, cf.
   phase0). Fire-and-forget, pas de `Process` managé. Le daemon DMS rend la carte.
2. **Réglages : toggle on/off + seuil de sévérité mini** (`SelectionSetting` labellisé). Le
   seuil filtre les `added` avant notif **et** pilote le pulse.
3. **Layering** : le **service** (`Zabbix.qml`) calcule le delta et **émet un signal**
   `problemsAppeared(added)` (données, pur) ; la **vue** (`AuspexWidget`) fait les effets de
   bord (notify-send, pulse). Le service ne connaît ni notify-send ni l'animation.
4. **Baseline au 1er poll** : le premier commit réussi **établit la référence sans notifier**
   (sinon salve au démarrage). Ensuite seulement, tout `added` déclenche. Jamais de
   re-notification d'un problème déjà connu (garanti par `eventid` dans `diffProblems`).
5. **Groupement** : plusieurs `added` d'un coup → **une** notif résumée
   (« N nouveaux problèmes · 1 Disaster · 2 High ») ; un seul → carte détaillée
   (« host · trigger » / « sévérité · âge »). Texte produit par un helper **pur** de `format.js`.
6. **Urgence** : `critical` si la pire sévérité des `added` ≥ High (4), sinon `normal`
   (mappé sur `notify-send -u`). Helper pur.
7. **Pulse vs toggle** : le pulse du badge respecte le **seuil** mais reste indépendant du
   toggle notifications (le toggle ne coupe que les notifs desktop ; le pulse est un indice
   discret in-barre). *(à confirmer en revue — inversable trivialement.)*

## Périmètre

**In scope :** delta `added` côté service + signal, notif desktop groupée/détaillée avec
urgence, pulse badge, réglages (toggle + seuil), dep `libnotify`, doc.

**Out of scope :** notif sur `resolved` (DESIGN ne notifie que `added`), son, actions dans la
notif (ack/close = écriture, hors invariant lecture seule), historique de notifs (le daemon
DMS le tient déjà), quick-links (plan dédié séparé).

## Fichiers touchés

- [ ] `src/model/format.js` — `notificationContent(added, now)` + `notificationUrgency(added)` (purs).
- [ ] `tests/tst_model.qml` — tests inline des deux helpers.
- [ ] `src/view/Zabbix.qml` — delta au commit, signal `problemsAppeared`, baseline.
- [ ] `src/view/AuspexWidget.qml` — `import Quickshell`, émission notify-send, pulse badge, cfg readers.
- [ ] `src/view/Settings.qml` — `ToggleSetting notifyEnabled` + `SelectionSetting notifyMinSeverity`.
- [ ] `nix/hm-module.nix` — `pkgs.libnotify` dans `home.packages`.
- [ ] `plugin.json` — `requires` += `"notify-send"`.
- [ ] `README.md` / `DESIGN.md` — état v0.4.0 + réglages notif.

## Étapes atomiques (chacune = 1 commit)

### Étape 1 : Helpers de notification (purs, testés inline)
**Description :** dans `format.js` : `notificationContent(added, nowMs)` → `{ title, body }`
(1 seul : `host · trigger` / `severityLabel · relativeTime` ; plusieurs : `N nouveaux
problèmes` / résumé `k Sévérité` décroissant, non nuls) ; `notificationUrgency(added)` →
`"critical"|"normal"`. Tests inline (`tst_model.qml`) avec `now` figé.
**Vérification :** `just ci` (2 tests de plus).
**Commit :** `feat(model): helpers de contenu et d'urgence de notification`

### Étape 2 : Service — delta `added` + signal (baseline au 1er poll)
**Description :** `Zabbix.qml` : `signal problemsAppeared(var added)`, `property var
_prevProblems: []`, `property bool _hasBaseline: false`. Dans `_commit(list)` : `diff =
Model.diffProblems(_prevProblems, list)` ; `_prevProblems = list` ; si `_hasBaseline` et
`diff.added.length > 0` → `problemsAppeared(diff.added)` ; puis `_hasBaseline = true`. Le
delta se calcule sur l'état réel (best-effort : un `_fail` ne réinitialise pas la baseline).
**Vérification :** `just ci` (inchangé) ; comportement en manuel (mock : ajouter un problème
entre deux polls → signal ; 1er poll → silencieux).
**Commit :** `feat(zabbix): émettre le delta added (silencieux au 1er poll)`

### Étape 3 : Réglages — activation + seuil de sévérité
**Description :** `Settings.qml` : `ToggleSetting notifyEnabled` (défaut `true`) et
`SelectionSetting notifyMinSeverity` (options `{value,label}` de 0=« Toutes » à 5=« Disaster
seulement », défaut `"0"`). `AuspexWidget` : `cfgNotifyEnabled`, `cfgNotifyMinSeverity`
(readonly, lus de `pluginData`, défauts sûrs).
**Vérification :** `just ci` ; réglages visibles/persistants (manuel).
**Commit :** `feat(view): réglages notifications (activation + seuil de sévérité)`

### Étape 4 : Notification desktop (notify-send)
**Description :** `AuspexWidget` : `import Quickshell` ; `Connections { target: svc;
function onProblemsAppeared(added) }` → filtrer `added` par `cfgNotifyMinSeverity`, et si
`cfgNotifyEnabled` et reste non vide : construire `{title,body}` (Format), `urgency`
(Format), icône, puis `Quickshell.execDetached(["notify-send","-a","Auspex","-u",urgency,
"-i",icon,title,body])`.
**Vérification :** `just ci` ; manuel : mock qui ajoute 1 puis N problèmes → 1 carte détaillée
puis 1 carte groupée ; toggle off → rien ; seuil High → un Warning ne notifie pas.
**Commit :** `feat(view): notification desktop sur nouveau problème (notify-send)`

### Étape 5 : Pulse du badge
**Description :** `AuspexWidget` : état transitoire `_pulsing` déclenché quand un `added`
qualifiant (≥ seuil) apparaît ; anneau `pulse` autour du badge/icône (1.8s, couleur = pire
sévérité des `added`), auto-arrêt après quelques cycles ou à l'ouverture du popout.
**Vérification :** `just ci` ; manuel : nouveau problème → l'anneau pulse ; RAS/ancien → non.
**Commit :** `feat(view): pulse du badge à l'apparition d'un nouveau problème`

### Étape 6 : Dépendance notify-send (nix + manifest)
**Description :** `nix/hm-module.nix` : `home.packages = [pkgs.curl pkgs.libnotify]`.
`plugin.json` : `requires` += `"notify-send"`.
**Vérification :** `just ci` ; `nix develop`/build hm-module (relecture ; réel en manuel).
**Commit :** `feat(nix): dépendance notify-send (libnotify) au runtime`

### Étape 7 : Doc — notifications livrées
**Description :** `README.md` (état v0.4.0, réglages notif) et `DESIGN.md` (note
d'implémentation : notify-send, baseline, groupement, seuil). MAJ commentaire d'en-tête
d'`AuspexWidget`/`Zabbix.qml` si utile.
**Vérification :** relecture ; `just ci`.
**Commit :** `docs: notifications v0.4.0`

### Étape 8 : Préparer la release (bump + changelog)
**Description :** `plugin.json.version` → `0.4.0` ; `just changelog` (généré `--tag v0.4.0`
pour dater la section) et relire le diff. Rend la branche release-ready ; **l'utilisateur**
posera le tag `v0.4.0` après merge (git hybride).
**Vérification :** `jq` valide, `just ci`, `CHANGELOG.md` cohérent.
**Commit :** `chore: préparer la release v0.4.0 (version + changelog)`

## Portes de qualité (clôture)

- [ ] `just ci` vert ; goldens **inchangés** (aucune transform touchée).
- [ ] `manual_tests.md` exécuté : 1er poll silencieux, ajout → notif, groupement, seuil,
      toggle off, pulse.
- [ ] Doc synchronisée ; commits atomiques sur `feat/v0.4.0-notifications`.
- [ ] **L'utilisateur** relit, merge, bump `plugin.json`→`0.4.0` (ou étape dédiée), tag `v0.4.0`.
