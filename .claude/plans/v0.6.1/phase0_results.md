# Phase 0 — Audit avant code (plan v0.6.1)

**Commande prescrite :** `nix develop --command just ci`
**Résultat :** non exécutable dans cet environnement — `nix`, `qmllint`,
`qmlformat`, `qmltestrunner`, `quickshell`, `just` sont tous absents du
sandbox (vérifié via `which`). Aucun des trois gates (`fmt-check`, `lint`,
`test`) n'a donc pu être lancé réellement.

**Palliatif retenu :** les transforms visés (`parseProblems`, `parseTriggers`,
`joinProblems`) sont du JS pur sans dépendance Qt (`.pragma library`, pas
d'import QtQuick). Ils ont été rejoués sous Node.js (`node v26.5.1`,
disponible) en extrayant le corps des fonctions, pour valider chaque cas
golden (ancien + nouveau) avant/après le patch. Ce n'est **pas** un
remplacement de `just ci` (qui couvre aussi `fmt`/`lint` QML et le runner Qt
Quick Test réel) — à faire tourner par l'utilisateur avant merge.

**État du dépôt avant code :** `origin/main` à jour (`38fa582`), working tree
propre après `git checkout -b fix/filter-disabled-trigger-problems
origin/main`. Aucune branche de plan en cours non mergée détectée (la branche
GitHub auto-créée `8-filter-triggers-to-only-show-problems-from-an-active-trigger`
sur l'issue #8 est vide/identique à `main`, non utilisée ici).
