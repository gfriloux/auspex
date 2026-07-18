# Phase 0 — Audit avant v0.4.0 (notifications)

**Date :** 2026-07-18
**Branche :** `feat/v0.4.0-notifications` (depuis `main`, v0.3.0 publié)

## `nix develop --command just ci`

- **exit 0.** fmt-check ✅ · lint (qmllint exit 0) ✅ · test **24 passed, 0 failed**.

## Constats (point de départ)

- **Le delta n'est PAS encore calculé côté service.** `Model.diffProblems(prev, curr)` existe
  et est testé (inline `test_diffProblems_noChange`), mais `Zabbix.qml._commit()` ne le calcule
  pas et n'expose ni signal ni `lastAdded`. (La mémoire projet disait « le service calcule déjà
  diffProblems » — **inexact** : c'est la couche `model` qui l'a.)
- **Mécanisme de notif = `notify-send`.** DMS n'expose pas d'API d'émission : son
  `Services/NotificationService.qml` est le *daemon* (récepteur freedesktop). DMS lui-même
  émet ses notifs via `Quickshell.execDetached(["notify-send", …])` (cf. `PortalService.qml`,
  `SettingsData.qml`). C'est la voie idiomatique : `notify-send` → daemon DMS → carte Catppuccin.
- **Réglages** : `Settings.qml` utilise `ToggleSetting`, `SliderSetting`, `StringSetting`,
  `SelectionSetting` (options `{value,label}`, valeur string) est dispo pour un seuil labellisé.
- **hm-module** : `home.packages = [pkgs.curl]` → ajouter `pkgs.libnotify` (fournit notify-send).
- `plugin.json.requires = ["curl"]` → ajouter `"notify-send"`.

## Conclusion

v0.4.0 touche `view` (service delta + émission notif + pulse badge, Settings), `model`
(`format.js` : helpers purs de contenu/urgence de notif, testés inline — **hors golden**),
`nix` (libnotify) et `doc`. **Aucun changement de transform `query`/`model` → goldens
inchangés.**
