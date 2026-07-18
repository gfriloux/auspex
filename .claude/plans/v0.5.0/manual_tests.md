# Tests manuels — v0.5.0 (quick-links web)

`just ci` couvre le modèle (goldens) et les helpers d'URL (inline). L'ouverture réelle d'un
onglet navigateur n'est pas automatisable ici → instance de dev.

## Environnement

`just mock` (scénario `ok`) + `just dev-bar`. Un navigateur par défaut doit être configuré
(xdg-open / Qt.openUrlExternally).

## Quick-links au survol

- [ ] Survol d'une ligne de problème → une **rangée d'icônes** apparaît à droite (fondu) :
      `open_in_new` (problème) + icône host.
- [ ] Clic sur **problème** → ouvre un onglet sur `…/tr_events.php?triggerid=…&eventid=…`
      (les bons ids du problème survolé).
- [ ] Clic sur **host** → ouvre un onglet sur `…/zabbix.php?action=problem.view&hostids[]=…`
      (le bon hostid).
- [ ] Un problème **orphelin** (host inconnu, hostid vide) → l'icône **host est masquée**
      (URL vide), l'icône problème reste.
- [ ] La ligne ne « saute » pas au survol (les icônes sont en overlay, pas dans le flux).

## Base d'URL & templates

- [ ] Avec l'URL d'API `https://zabbix.example.com/api_jsonrpc.php`, `{base}` vaut
      `https://zabbix.example.com` (le `/api_jsonrpc.php` est retiré).
- [ ] Settings affiche les deux **templates** (problème, host) avec les défauts, éditables.
- [ ] **Vider** un template → l'icône correspondante disparaît (désactivation propre).
- [ ] Modifier un template (ex. passer host en `filter_hostids[]={hostid}&filter_set=1`) →
      le lien suit la nouvelle forme sans redémarrage (ou après réouverture du popout).

## ⚠️ À confirmer sur la vraie prod (non disponible au moment du dev)

- [ ] Les **formats d'URL par défaut** ouvrent bien la bonne page sur **ton** instance 7.0.
      Sinon, ajuster les templates dans Settings (aucun changement de code requis).

## Dépendance runtime

- [ ] `xdg-open` présent (via `xdg-utils` du hm-module) ; `plugin.json.requires` le liste.

## Reporté / hors périmètre

- **SSH host** : pas de solution propre (adresse/terminal/port) → plan futur.
- **Lien graphe** : nécessite des appels API supplémentaires + choix du graphe → plan futur.
- Pose du tag `v0.5.0` : **utilisateur**.
