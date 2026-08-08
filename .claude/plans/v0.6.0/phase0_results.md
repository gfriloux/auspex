# Phase 0 — audit du dépôt (v0.6.0)

**Date :** 2026-08-08
**Branche de départ :** `main` @ `f6fedf0` — working tree **propre**.

## Portes

```
nix develop --command just ci
→ fmt-check : OK
→ lint      : OK (baseline de warnings d'import DMS, exit 0)
→ test      : Totals: 29 passed, 0 failed, 0 skipped, 81ms
```

**Verdict : portes vertes avant de coder.**

## État réel de la couche HTTP

`src/view/Zabbix.qml` exécute chaque appel JSON-RPC via `Process` + `curl` :

```qml
["curl", "-s", "--max-time", "10",
 "-H", "Content-Type: application/json",
 "-H", "Authorization: Bearer " + root.token, /* [-k] */
 "-d", <body>, root.url]
```

Le token est donc un **argument de processus**. Sous Linux, `/proc/<pid>/cmdline` est
lisible **par tout utilisateur local** (mode 0444, sans `hidepid`) : n'importe quel compte
de la machine peut lire le token pendant la fenêtre du poll (30 s d'intervalle par défaut,
donc en pratique en boucle). Le commentaire actuel de `Zabbix.qml` (« visible du seul
utilisateur courant ») **sous-estime l'exposition**. C'est l'objet de l'issue #5.

## Inventaire des mentions de curl

| Fichier | Nature |
|---|---|
| `src/view/Zabbix.qml` | code + commentaires d'en-tête, `_curlCmd`, messages d'erreur, `console.warn` |
| `src/view/Settings.qml:51` | description du toggle `insecure` (« curl -k ») |
| `src/view/AuspexWidget.qml:18,42` | `cfgInsecure` → propriété `insecure` du service |
| `plugin.json` | `"requires": ["curl", …]` |
| `nix/hm-module.nix` | `home.packages = [pkgs.curl …]` + commentaire |
| `flake.nix` | dev shell : `curl` + commentaire « Runtime du service » |
| `README.md` | 3 emplacements (statut, plan du code, configuration/sécurité) |
| `CHANGELOG.md`, `.claude/plans/v0.2.0/`, `.claude/plans/v0.4.0/` | **historique** — hors périmètre (cf. plan.md) |

`DESIGN.md` et `CLAUDE.md` ne nomment **jamais** curl : ils parlent de « HTTP » et du
« service ». Aucun invariant de `DESIGN.md` n'est touché par ce changement — le transport
n'est pas un invariant, l'auth Bearer et la lecture seule le sont, et ils sont préservés.

## Expériences — ce que `XMLHttpRequest` sait faire dans ce runtime

Bancs d'essai jetables (scratch, non commités) : `qmltestrunner` offscreen (Qt 6.11.1, le
runtime des portes) contre un serveur d'écho Python renvoyant headers + corps reçus.

| Capacité curl actuelle | XHR | Résultat mesuré |
|---|---|---|
| `-H "Authorization: Bearer …"` | `setRequestHeader` | ✅ le serveur reçoit `authorization: Bearer …` |
| POST + corps JSON | `send(JSON.stringify(body))` | ✅ corps intact |
| `-H "Content-Type: application/json"` | idem | ⚠️ Qt **ajoute** `;charset=UTF-8` (idem en envoyant un `ArrayBuffer` : non contournable) |
| HTTPS avec CA de confiance | — | ✅ `status=200` contre un hôte public |
| `--max-time 10` | `xhr.timeout` / `ontimeout` | ❌ **absents du runtime QML** (`"timeout" in xhr === false`) ; l'affectation crée une propriété JS morte |
| — | `Timer` + `xhr.abort()` | ✅ substitut validé : serveur qui n'a jamais répondu → abort à 1,2 s → `readyState=4`, `status=0` |
| `-k` (certificat auto-signé) | — | ❌ **aucun équivalent** : `status=0`. Qt refuse tout certificat hors magasin **système**, et n'honore pas `SSL_CERT_FILE` (curl, lui, réussit avec la même variable) |

Détails utiles pour l'implémentation :

- Un échec réseau (connexion refusée, hôte injoignable, **échec TLS**) donne toujours
  `readyState=4` + `status=0`, sans détail. **On ne peut pas distinguer** un problème de
  certificat d'un problème de joignabilité depuis QML → cf. décision D3 du plan.
- `abort()` déclenche bien `onreadystatechange` en `DONE` : le watchdog est observable
  comme n'importe quel autre échec.
- Le modèle de permissions DMS n'a **pas** de notion de réseau (`PluginSettings.qml` ne
  contrôle que `settings_write`) : rien à déclarer côté plugin pour XHR.
