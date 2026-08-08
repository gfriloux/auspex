# Tests manuels — v0.6.0 (poll via XMLHttpRequest)

Ce que les portes ne couvrent pas : le vrai HTTP, le rendu DMS/Wayland, le comportement TLS.
Deux terminaux : `just mock [scenario] [port]` d'un côté, `just dev-bar` de l'autre.
URL du plugin : `http://127.0.0.1:8384/api_jsonrpc.php`, token quelconque.

## Déjà vérifié automatiquement (banc d'essai jetable, hors dépôt)

`Zabbix.qml` n'importe plus que QtQuick + les `.js` : il s'instancie donc dans
`qmltestrunner` hors Quickshell. Un banc d'essai scratch a fait tourner le **vrai service**
contre le **vrai mock** et des serveurs jetables — 5/5 :

| Scénario | Résultat |
|---|---|
| mock `ok` | `live`, 8 problèmes, jointure host faite — **le `Content-Type` avec charset passe le contrôle façon Zabbix** |
| port fermé | `Zabbix injoignable (connexion refusée)`, `_busy` libéré |
| serveur qui ne répond jamais | `Zabbix injoignable (délai dépassé)` au watchdog, `_busy` libéré |
| mock `unauthorized` | statut `unauthorized` |
| HTTPS **certificat auto-signé** | `… réseau ou certificat TLS non approuvé …`, en < 2 s (rejet à la poignée de main, bien avant le watchdog) |

Ça ne dispense d'aucun test ci-dessous : le rendu DMS et la **vraie instance** restent
non couverts. Ça les cible.

## Le point qui décide (D5)

- [ ] **Contre une vraie instance Zabbix 7.0** : le poll aboutit malgré le
      `Content-Type: application/json;charset=UTF-8` ajouté par Qt.
      Échec ⇒ basculer sur `application/json-rpc` (cf. plan D5) et re-tester.

## Fonctionnel (mock)

- [ ] `just mock ok` → badge peuplé, cockpit listant les 8 problèmes, en-tête `live`.
- [ ] `just mock empty` → état vide, badge sans compteur.
- [ ] `just mock unauthorized` → bannière « Vérifier l'API token », statut `unauthorized`.
- [ ] `just mock error` → bannière d'erreur, **dernier état connu conservé**.
- [ ] Mock arrêté en cours de route → `Zabbix injoignable (connexion refusée)` dans la
      bannière, puis retour à `live` au redémarrage du mock (sans toucher au widget).
- [ ] Bouton « Réessayer » de la bannière : relance bien un poll.
- [ ] Nouveau problème injecté → notification desktop + pulse du badge (non régressé).

## Délai / watchdog (D1)

- [ ] Serveur qui accepte mais ne répond jamais (`python3 -c` d'attente, ou mock suspendu
      par `SIGSTOP`) → au bout de **10 s** : `Zabbix injoignable (délai dépassé)`.
- [ ] Après ce délai, le poll suivant repart normalement (pas de `_busy` coincé : le
      compteur de cadence du pied de cockpit continue d'avancer).

## TLS (D2/D3)

- [ ] Instance en **certificat auto-signé**, CA absente du magasin système →
      `Zabbix injoignable — réseau ou certificat TLS non approuvé …`.
- [ ] Même instance, CA ajoutée au magasin système (NixOS :
      `security.pki.certificateFiles = [ ./zabbix-ca.pem ];`, puis re-login) → poll `live`.
- [ ] Le réglage « Certificat TLS non vérifié » **n'apparaît plus** dans le panneau DMS.

## Ce que tout ça sert à prouver (issue #5)

- [ ] Pendant un poll actif : `ps aux | grep -i bearer` et
      `grep -al Bearer /proc/*/cmdline 2>/dev/null` → **aucun résultat**.
      (Avant le changement, le token apparaissait dans l'argv de curl.)
- [ ] Aucun processus `curl` n'est lancé par le widget : `pgrep -af curl` reste vide
      pendant plusieurs cycles de poll.
