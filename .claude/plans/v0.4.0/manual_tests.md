# Tests manuels — v0.4.0 (notifications)

`just ci` couvre les helpers purs. L'émission `notify-send`, la réception par le daemon DMS
et le pulse ne sont **pas** automatisables ici → à dérouler dans l'instance de dev.

## Environnement

Deux terminaux (`nix develop`) : `just mock` (scénario `ok`) + `just dev-bar`. Le daemon de
notifications de DMS doit tourner (c'est le cas dans une session DMS normale).

Pour simuler l'**apparition** d'un problème entre deux polls : lancer `just mock` sur un
scénario à N problèmes, laisser auspex établir la baseline, puis basculer le mock vers un
scénario avec un problème de plus (ou éditer le mock) → au poll suivant, delta `added`.

## Baseline & delta

- [ ] **1er poll** (démarrage) : la liste se remplit **sans** notification (baseline établie
      silencieusement), même s'il y a déjà des problèmes.
- [ ] Un **nouveau** problème apparaît au poll suivant → **une** notification desktop.
- [ ] Un problème **déjà connu** qui reste présent ne re-notifie **jamais** aux polls suivants.
- [ ] Un problème **résolu** (disparaît) ne notifie pas (seul `added` notifie).

## Contenu de la notification

- [ ] **Un seul** nouveau : titre `host · trigger`, corps `Sévérité · âge`.
- [ ] **Plusieurs** d'un coup : une **notification groupée** « N nouveaux problèmes · 1
      Disaster · 2 High » (compte par sévérité, décroissant, non nuls).
- [ ] Urgence : un lot contenant High/Disaster passe en `critical` (rendu plus insistant du
      daemon) ; sinon `normal`.

## Réglages

- [ ] Settings affiche **Notifications** (toggle, défaut activé) et **Seuil de sévérité**
      (sélection labellisée, défaut « Toutes »).
- [ ] Toggle **off** → aucune notification desktop sur nouveau problème.
- [ ] Seuil **High et +** → un nouveau **Warning** ne notifie pas ; un nouveau **Disaster** oui.
- [ ] Les réglages persistent après redémarrage de DMS.

## Pulse du badge

- [ ] À l'apparition d'un nouveau problème **≥ seuil**, un **anneau pulse** entoure le badge
      (couleur = pire sévérité du lot), puis s'arrête.
- [ ] Aucun pulse au 1er poll (baseline), ni pour un problème déjà connu.
- [ ] (Selon décision §7 du plan) le pulse reste indépendant du toggle notifications — à
      confirmer/ajuster en revue.

## Dépendance runtime

- [ ] `notify-send` est présent dans le PATH de la session DMS (via `libnotify` du hm-module).
- [ ] `plugin.json` liste `notify-send` dans `requires`.

## Reporté / hors périmètre

- Notif sur `resolved`, son, actions dans la notif (écriture = hors lecture seule).
- Quick-links de délégation → plan dédié séparé.
- Pose du tag `v0.4.0` : **utilisateur** (jamais Claude).
