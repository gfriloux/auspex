## Plan : v0.6.0 — poll HTTP via `XMLHttpRequest` (fin de curl)

**Type :** refactor (transport) + suppression d'un réglage
**Objectif :** exécuter les appels JSON-RPC depuis le service QML lui-même, avec
`XMLHttpRequest`, et retirer curl du code, des dépendances et de la doc.
**Pourquoi :** issue **#5**. Avec `Process` + curl, le token est un **argument de
processus** ; `/proc/<pid>/cmdline` est lisible par **tout utilisateur local** (cf.
`phase0_results.md`). Un token read-only reste un secret : il n'a rien à faire dans une
argv relue en boucle toutes les 30 s. Avec XHR, le token ne quitte jamais le processus DMS
— il part directement dans le header de la requête.
**Étage(s) :** `model` (helper de message), `view` (service + cockpit + réglages), `nix`, `doc`

---

### Périmètre

**In scope**

- `src/view/Zabbix.qml` : transport XHR, watchdog de délai, mapping des erreurs.
- `src/view/Cockpit.qml` : la bannière d'erreur affiche enfin `service.errorMessage`.
- `src/view/Settings.qml` + `src/view/AuspexWidget.qml` : suppression du toggle `insecure`.
- `src/model/format.js` : helper **pur** de message d'erreur réseau (+ tests inline).
- `plugin.json`, `nix/hm-module.nix`, `flake.nix` : curl retiré des dépendances.
- `README.md` (3 emplacements) + `DESIGN.md` (une ligne sur le transport).
- `scripts/zabbix-mock.py` : valider le `Content-Type` comme le fait Zabbix.

**Out of scope**

- **`CHANGELOG.md` et `.claude/plans/v0.2.0|v0.4.0`** : ce sont des **archives**. Le
  changelog est **régénéré par git-cliff** depuis les messages de commit — le réécrire à la
  main serait annulé au prochain `just changelog`. Les plans passés décrivent ce qui a été
  fait à l'époque ; les réécrire falsifierait l'historique de décision. Ces mentions de curl
  restent, et c'est volontaire.
- Tout invariant `DESIGN.md` : auth **Bearer**, **lecture seule**, problème = unité,
  agnostique à l'instance — tous préservés. Le transport n'est pas un invariant.
- Le stockage du token côté DMS (toujours en clair dans `pluginData`) : autre sujet, autre
  plan si besoin.

---

### Décisions techniques

**D1 — `xhr.timeout` n'existe pas dans le runtime QML** (mesuré : `"timeout" in xhr ===
false`, cf. phase 0). Le `curl --max-time 10` est remplacé par un **`Timer` de 10 s +
`xhr.abort()`**. Validé en banc d'essai : l'abort ressort en `readyState=4`/`status=0`,
donc traité comme n'importe quel échec. Une réponse tardive d'une requête déjà abandonnée
est ignorée (comparaison d'identité sur l'objet XHR courant).

**D2 — Le toggle « certificat TLS non vérifié » disparaît.** Aucun moyen, depuis QML, de
sauter la vérification : Qt refuse tout certificat hors magasin **système** et n'honore pas
`SSL_CERT_FILE` (mesuré). Garder le réglage en le rendant inopérant serait un mensonge
d'interface. Le chemin documenté devient : **ajouter la CA au magasin système** (NixOS :
`security.pki.certificateFiles`). Un repli sur `curl -k` a été écarté : il rouvrirait la
fuite de token exactement pour les instances les plus exposées.

**D3 — Message d'erreur dédié, honnête sur son incertitude.** XHR rend `status=0` sans
détail pour *tous* les échecs réseau : on **ne peut pas** distinguer un certificat refusé
d'un hôte injoignable. Le message est donc conditionné au **schéma de l'URL** :

| Cas | Message |
|---|---|
| abort du watchdog | `Zabbix injoignable (délai dépassé)` |
| `status=0`, URL `http://` | `Zabbix injoignable (connexion refusée)` |
| `status=0`, URL `https://` | `Zabbix injoignable — réseau ou certificat TLS non approuvé (ajouter la CA au magasin système)` |
| `status` ≠ 200 | `Réponse HTTP <code>` |

Ce mapping est un **helper pur** de `format.js`, testé — pas du texte noyé dans le service.

**D4 — La bannière d'erreur du cockpit affiche `service.errorMessage`.** Aujourd'hui elle
affiche un texte **en dur** (`Zabbix injoignable — nouvelle tentative bientôt.`) et jette le
message du service : sans ce câblage, D3 serait invisible. Repli sur le texte actuel si
`errorMessage` est vide.

**D5 — `Content-Type: application/json` devient `application/json;charset=UTF-8`.** Qt
ajoute le charset et c'est **non contournable** (vérifié aussi en envoyant un
`ArrayBuffer`). Zabbix découpe l'en-tête sur `;` avant de comparer, donc ça doit passer —
**mais ce n'est pas vérifié contre une vraie instance**. Deux filets : le mock applique
désormais la même validation que Zabbix, et c'est le **premier point** de `manual_tests.md`.
Si une vraie instance refusait, le repli serait un `Content-Type: application/json-rpc`
(même traitement côté Zabbix) — sans effet sur l'architecture.

**D6 — Version `0.6.0`** (mineure, pas patch) : un réglage utilisateur disparaît et une
dépendance runtime tombe. Commit principal marqué `BREAKING CHANGE` pour le changelog.

---

### Fichiers touchés

- [ ] `src/model/format.js` + `tests/tst_model.qml`
- [ ] `src/view/Zabbix.qml`
- [ ] `src/view/Cockpit.qml`
- [ ] `src/view/Settings.qml`
- [ ] `src/view/AuspexWidget.qml`
- [ ] `scripts/zabbix-mock.py`
- [ ] `plugin.json`, `nix/hm-module.nix`, `flake.nix`
- [ ] `README.md`, `DESIGN.md`
- [ ] `CHANGELOG.md` (régénéré, dernière étape)

Aucun `tests/fixtures/` ni `tests/golden/` ne bouge : **`query` et `model` ne sont pas
touchés** par un changement de transport. Si un golden bougeait, ce serait le signe qu'on a
dérapé hors du périmètre.

---

### Étapes atomiques

#### Étape 1 : helper pur de message d'erreur réseau
**Description :** `format.js` — `networkErrorMessage(url, kind)` (`kind` :
`"timeout" | "unreachable" | "http"`), selon la table D3. Tests inline dans
`tests/tst_model.qml` : délai dépassé, `http://` injoignable, `https://` injoignable
(mentionne le certificat), code HTTP.
**Vérification :** `nix develop --command just ci` (tests > 29)
**Commit :** `feat(model): message d'erreur réseau selon le schéma d'URL`

#### Étape 2 : le service poll en XMLHttpRequest
**Description :** `Zabbix.qml` — `_curlCmd`/`probProc`/`trigProc` remplacés par un `_post(body, onOk)`
générique (XHR, headers `Content-Type` + `Authorization: Bearer`), watchdog `Timer` 10 s →
`abort()`, garde anti-réponse-tardive, erreurs via le helper de l'étape 1. L'enchaînement
`problem.get` → `trigger.get` et toute la logique de `_commit`/delta/baseline sont
**inchangés**. Suppression de la propriété `insecure` + du `cfgInsecure` d'`AuspexWidget` +
du `ToggleSetting` de `Settings.qml`. En-tête de commentaire réécrit (plus de curl, mention
explicite : le token ne sort pas du processus). `Cockpit.qml` : bannière = `errorMessage`
(D4). Doc du même coup (règle « doc dans le même commit ») : `README.md` (statut, plan du
code, section configuration/sécurité + note CA système) et `DESIGN.md` (le service exécute
le HTTP en XHR, pas de saut de vérification TLS).
**Vérification :** `just ci` ; puis `just mock` + `just dev-bar` (cf. `manual_tests.md`)
**Commit :** `refactor(view): poll HTTP via XMLHttpRequest` + footer `BREAKING CHANGE:`
(le toggle « certificat TLS non vérifié » disparaît ; une instance en auto-signé demande
désormais la CA dans le magasin système)

#### Étape 3 : le mock valide le Content-Type comme Zabbix
**Description :** `scripts/zabbix-mock.py` — rejeter (HTTP 415, corps JSON-RPC d'erreur)
tout `Content-Type` dont la partie avant `;` n'est pas
`application/json` / `application/json-rpc` / `application/jsonrequest`. Filet de dev pour D5.
**Vérification :** `just mock` + `just dev-bar` → le poll passe ; un POST à la main avec un
mauvais type est refusé.
**Commit :** `chore(dev): le mock valide le Content-Type comme Zabbix`

#### Étape 4 : curl hors des dépendances
**Description :** `plugin.json` (`requires` : curl retiré, `notify-send`/`xdg-open`
gardés), `nix/hm-module.nix` (`home.packages` sans `pkgs.curl`, commentaire à jour),
`flake.nix` (dev shell : curl retiré avec son commentaire « runtime du service »).
La permission `process` **reste** : `notify-send` et `xdg-open` passent toujours par
`execDetached`.
**Vérification :** `nix develop --command just ci` + `nix flake check`
**Commit :** `chore(nix): retirer curl des dépendances runtime`

#### Étape 5 : release v0.6.0
**Description :** `plugin.json` → `0.6.0`, `just changelog`, relecture du diff.
**Vérification :** `just ci`
**Commit :** `chore: préparer la release v0.6.0 (version + changelog)`

---

### Portes de qualité

- [ ] `just ci` passe à **chaque** étape
- [ ] Aucun golden modifié (sinon : hors périmètre, on s'arrête)
- [ ] `grep -ri curl src/ README.md DESIGN.md CLAUDE.md plugin.json flake.nix nix/` → vide
- [ ] Doc synchronisée dans le même commit que le code
- [ ] Commits atomiques sur `refactor/v0.6.0-xhr` ; **merge/push/tag par l'utilisateur**
- [ ] `manual_tests.md` exécuté (au minimum les scénarios mock)

### Risques

| Risque | Parade |
|---|---|
| Zabbix refuse `application/json;charset=UTF-8` (D5) | Mock durci (étape 3) + 1er test manuel ; repli `application/json-rpc` |
| Watchdog qui laisse le service coincé en `_busy` | `_busy` remis à faux dans **tous** les chemins d'échec ; scénario « serveur muet » dans `manual_tests.md` |
| Message TLS trompeur sur un vrai souci réseau (D3) | Formulation « réseau **ou** certificat » — l'incertitude est dite, pas masquée |
| Un utilisateur en auto-signé se retrouve bloqué | README : marche à suivre CA système (NixOS `security.pki.certificateFiles`) + message d'erreur qui pointe dessus |
