# Tests manuels — v0.2.0 (service + badge + home-manager)

La couche données reste golden-testée (`just ci`). v0.2.0 ajoute du QML Quickshell et du
HTTP réel : **non automatisables ici** (pas de DMS/Wayland ni d'instance Zabbix dans le
dev shell). À exécuter sur la machine cible.

## Installation & activation

- [ ] Ajouter le module home-manager (`inputs.auspex` + `programs.auspex.enable = true`),
      `home-manager switch` réussit.
- [ ] `~/.config/DankMaterialShell/plugins/Auspex/` contient `plugin.json` + `src/`.
- [ ] `curl` est présent dans le PATH de la session.
- [ ] DMS → Settings → Plugins : **Auspex** apparaît et s'active sans erreur (regarder les
      logs quickshell).

## Réglages

- [ ] Le panneau de réglages affiche URL, token, intervalle (slider 5-300 s), toggle TLS.
- [ ] Saisir URL + token d'un utilisateur **read-only** ; les valeurs persistent après
      redémarrage de DMS.

## Service & badge (chemin nominal)

- [ ] Avec des problèmes actifs : le badge affiche le **compteur** et prend la **couleur de
      la pire sévérité** (Disaster rouge, High maroon, …). Icône `radar`.
- [ ] Sans problème (RAS) : pas de badge, icône discrète.
- [ ] Le popout liste les problèmes : bord-gauche coloré, host (mono), trigger, chip de
      sévérité, âge. Ligne acquittée/supprimée atténuée.
- [ ] L'état de connexion dans l'en-tête passe `polling` → `live` ; le poll se répète à
      l'intervalle réglé.

## Chemins d'erreur (best-effort)

- [ ] URL injoignable → en-tête `error`, bandeau rouge, **dernier état conservé** (pas de
      crash, pas de liste vidée).
- [ ] Token invalide → `unauthorized` + message « Vérifier l'API token… ».
- [ ] Certif auto-signé : sans le toggle → `error` ; toggle « TLS non vérifié » activé → OK.

## Points d'implémentation à confirmer (non testables hors DMS)

Ces choix suivent la doc/les patterns astropath mais n'ont pas pu être exécutés ici :

- [ ] `Quickshell.env("XDG_RUNTIME_DIR")` renvoie bien le dossier runtime (sinon fallback
      `/tmp`). Le fichier `…/auspex/curl.cfg` est créé en **0700**, contient l'URL + le
      header Bearer, et **le token n'apparaît pas dans `ps`** (`ps aux | grep curl`).
- [ ] Écriture impérative de `FileView` (`cfgFile.path = …; cfgFile.setText(…)`) fonctionne
      dans le contexte plugin (le poll part après le petit Timer de 60 ms).
- [ ] `Process` enchaîne bien problem.get puis trigger.get (le 2e dépend du 1er) ; la
      jointure host s'affiche correctement.
- [ ] Composants DMS résolus à l'exécution : `PluginComponent`, `DankIcon`, `StyledText`,
      `StyledRect`, `PluginSettings`, `StringSetting`, `SliderSetting`, `ToggleSetting`.

## Reporté

- Cockpit direction C complet (télémétrie, barre de résumé, filtres, états soignés) → v0.3.0.
- Notifications desktop + pulse « nouveau problème » (delta) → v0.4.0.
