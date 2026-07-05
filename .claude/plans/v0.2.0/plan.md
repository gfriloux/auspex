## Plan : v0.2.0 — service + badge + home-manager

**Type :** vue (service + widget) + nix + doc
**Objectif :** rendre auspex **installable et utilisable bout-en-bout** : un service qui
poll une vraie instance Zabbix 7.0 (HTTP), un **badge de barre** qui affiche l'état
(compteur + couleur de la pire sévérité), des **réglages** (URL / token / intervalle), et
l'**installation via home-manager**.
**Pourquoi :** mettre au sec la brique la plus risquée (HTTP + secret + install) avant la
finition UI. Le cockpit complet (direction C) et les notifications suivent en v0.3.0/v0.4.0.
**Étage(s) :** `model` (helpers) | `view` (service + widget + settings) | `nix` | `doc`

### Contexte & état du working tree

Part de `main` après merge de v0.1.0 + gel de la direction visuelle C (branche
`feat/v0.2.0-surface`, commit `docs: figer la direction visuelle C`). Couche données
déterministe en place (query + model + goldens). Aucun QML de vue encore, pas de
home-manager. Le `.dc.html` (réf pixel-perfect) est dans `tmp/` (non commité).

### Périmètre

**In scope :**
- `format.severityColor(n)` + `model.rpcError(res)` : petits helpers purs, inline-testés.
- Service `src/view/Zabbix.qml` : poll HTTP via `curl`/`Process`, orchestration deux
  appels (problem.get → trigger.get → join), expose `problems` / `worstSeverity` /
  `counts` / `connectionStatus` / `lastPollAt`.
- Badge `src/view/AuspexWidget.qml` : icône `radar`, compteur, **couleur = pire sévérité**.
- Popout **minimal** (liste brute host/trigger/sévérité/âge) pour que ce soit *utilisable* —
  PAS le cockpit complet (en-tête télémétrie, barre de résumé, filtres, états annexes =
  v0.3.0).
- `src/view/Settings.qml` : URL, token, intervalle de poll, toggle TLS non-vérifié.
- `nix/hm-module.nix` + export `flake.homeModules.default` ; `curl` en runtime ; MAJ `plugin.json`.

**Out of scope :**
- Cockpit direction C complet (télémétrie, barre de résumé, filtres, vide/chargement/erreur
  riches) → **v0.3.0**.
- Notifications desktop + pulse-sur-nouveau-problème (delta) → **v0.4.0**.
- Écriture (ack/close), multi-instance, quick-links de délégation → cap futur.

### Décisions techniques (validées)

1. **HTTP via `curl` + `Process`** (comme astropath lance `notmuch`). Gère les certifs
   auto-signés (toggle `insecure` → `-k`) et les timeouts, contrairement à `XMLHttpRequest`.
2. **Token en header curl (`-H`).** ~~Fichier de config `--config` sous `$XDG_RUNTIME_DIR`~~
   — approche abandonnée en cours de route : trop fragile dans le contexte Quickshell
   (timing d'écriture `FileView`, `Quickshell.env`) → `curl: option --config: error reading
   a file`. Le service passe donc `-H "Authorization: Bearer …"` directement. Le token
   n'apparaît que dans l'argv du process curl (visible du seul utilisateur courant),
   acceptable pour un token **read-only** ; durcissement possible plus tard sans changer
   l'interface. Le token reste hors des couches `query`/`model` et des fixtures (DESIGN inv. 3).
3. **Orchestration deux appels dans le service** : problem.get → collecte des objectid
   (triggerids) → trigger.get(selectHosts) → `Model.joinProblems`. Puis `worstSeverity` /
   `countsBySeverity`. Le service est de la *glu* : la logique pure testée vit dans
   `query`/`model` (v0.1.0) ; l'orchestration réseau va en `manual_tests.md`.
4. **connectionStatus** : `live | polling | error | unauthorized`. Détection :
   code de sortie curl ≠ 0 → `error` ; `Model.rpcError(res)` non nul → `error` (ou
   `unauthorized` si le message évoque l'auth) ; sinon `live`. Best-effort : on garde le
   dernier `problems` connu en cas d'erreur (DESIGN inv. 7).
5. **Badge v0.2.0 = compteur + couleur, sans pulse.** Le pulse « nouveau problème » dépend
   du delta → il arrive avec les notifications en **v0.4.0**. Pas de pulse perpétuel.
6. **Secret dans les réglages DMS** (`settings_read/write`), en clair (token read-only) ;
   option « pointer un fichier » repoussée si besoin.

### Fichiers touchés

- [ ] `src/model/format.js` (+`severityColor`), `src/model/problems.js` (+`rpcError`)
- [ ] `tests/tst_model.qml` (inline : severityColor, rpcError)
- [ ] `src/view/Zabbix.qml` (service)
- [ ] `src/view/AuspexWidget.qml` (badge + popout minimal)
- [ ] `src/view/Settings.qml`
- [ ] `nix/hm-module.nix`, `flake.nix` (export homeModules + curl), `plugin.json`
- [ ] `README.md`, `.claude/plans/v0.2.0/manual_tests.md`

### Étapes atomiques

#### Étape 1 : helpers de vue (severityColor, rpcError)
**Description :** `format.severityColor(n)` (mapping DESIGN 0-5 + défaut RAS/Overlay) ;
`problems.rpcError(res)` → message d'erreur JSON-RPC ou `null` (+ heuristique auth).
Inline-testés.
**Vérification :** `just ci`.
**Commit :** `feat(model): helpers severityColor et rpcError`

#### Étape 2 : service Zabbix (poll HTTP)
**Description :** `src/view/Zabbix.qml` : `Process`/`curl`, config file 0600, orchestration
problem.get→trigger.get→join, `worstSeverity`/`counts`, `connectionStatus`, `lastPollAt`,
`Timer` de poll, gestion d'erreur (best-effort). Pas de golden (glu réseau).
**Vérification :** `just ci` (lint/format) ; test réel en `manual_tests.md`.
**Commit :** `feat(view): service de poll Zabbix (curl/Process)`

#### Étape 3 : badge de barre + popout minimal
**Description :** `src/view/AuspexWidget.qml` : `PluginComponent`, icône `radar`, badge
compteur coloré par `worstSeverity` (via `severityColor`), lit URL/token/intervalle/insecure
depuis `pluginData`, instancie le service. `popoutContent` = liste brute des problèmes
(host/trigger/chip sévérité/âge), thème DMS.
**Vérification :** `just ci` ; rendu vérifié en `manual_tests.md`.
**Commit :** `feat(view): badge de barre et liste minimale`

#### Étape 4 : réglages
**Description :** `src/view/Settings.qml` : champs URL, token (masqué), intervalle de poll,
toggle TLS non-vérifié. Écrit dans `pluginData`.
**Vérification :** `just ci` ; réglages persistés vérifiés en `manual_tests.md`.
**Commit :** `feat(view): réglages (URL, token, intervalle, TLS)`

#### Étape 5 : packaging home-manager
**Description :** `nix/hm-module.nix` (assemble plugin.json + src, lie dans
`~/.config/DankMaterialShell/plugins/Auspex/`, `curl` en `home.packages`) ; export
`flake.homeModules.default` ; `curl` au dev shell ; MAJ `plugin.json`
(`requires:["curl"]`, `permissions` + `process`).
**Vérification :** `nix develop --command just ci` ; `nix flake check` ; install réelle en
`manual_tests.md`.
**Commit :** `feat(nix): module home-manager et packaging plugin`

#### Étape 6 : documentation
**Description :** `README.md` (installation home-manager, statut v0.2.0, réglages requis :
utilisateur Zabbix read-only + API token) ; `manual_tests.md` complété.
**Vérification :** relecture ; `just ci`.
**Commit :** `docs: installation home-manager et usage v0.2.0`

### Portes de qualité
- [ ] `just ci` passe (fmt-check + lint + test)
- [ ] `nix flake check` OK ; module home-manager s'évalue
- [ ] **Token jamais en argv** ni dans un fichier commité ; réglages hors dépôt
- [ ] Tests manuels exécutés (poll réel Zabbix 7.0, badge, install home-manager)
- [ ] Doc synchronisée (même commit), commits atomiques sur branche dédiée
