## Plan : Exclure les problèmes dont le trigger n'est plus actif (#8)

**Type :** bug
**Objectif :** `problemGet()` renvoie des problèmes liés à des triggers
désactivés (ou supprimés) ; ces problèmes ne se résolvent jamais côté Zabbix
(un trigger désactivé n'est plus réévalué) et s'accumulent dans l'affichage
Auspex au fil du temps.
**Pourquoi :** cf. issue #8 — bruit croissant dans le cockpit, non représentatif
de l'état réel de la supervision.
**Étage(s) :** `query`, `model`

### Décision technique

Deux options envisagées (cf. issue #8) :
- **A** : fusionner `problem.get` + `trigger.get` en un seul appel
  `trigger.get(monitored, only_true, selectHosts, selectProblems)`.
- **B** (retenue ici) : garder le pipeline à deux appels, mais (1) filtrer
  `trigger.get` côté serveur avec `monitored: true`, et (2) dans
  `joinProblems()`, écarter un problème dont le `triggerid` n'a pas de host
  résolu — au lieu de l'afficher avec un host vide (ancien comportement
  « best-effort »).

Option B retenue pour ce patch : diff minimal (2 fichiers), aucun changement
du format consommé par la vue QML, aucune incertitude sur les champs exposés
par `selectProblems` côté API Zabbix. L'option A part en issue de suivi
(refactor, hors scope ici — cf. issue dédiée).

### Fichiers touchés
- [x] `tests/fixtures/problems-trigger-disabled.json` (nouveau cas)
- [x] `tests/golden/problems-trigger-disabled.json` (nouveau cas)
- [x] `tests/cases.js` (enregistrer le nouveau cas)
- [x] `src/query/queries.js` (`triggerGetWithHosts` : `monitored: true`)
- [x] `src/model/problems.js` (`joinProblems` : filtre au lieu de fallback vide)
- [x] `tests/golden/problems-multi.json` (même transform → golden mis à jour :
      la ligne « Orphan trigger problem », qui modélisait déjà exactement ce
      cas, est désormais écartée au lieu d'afficher un host vide)

### Étapes atomiques

#### Étape 1 : Fixture + golden de régression
**Description :** Nouveau cas `problems-trigger-disabled` : deux problèmes,
l'un dont le trigger est présent dans la réponse `trigger.get` (host résolu),
l'autre dont le trigger est absent (simulant un trigger désactivé, exclu par
`monitored: true`). Le golden encode le comportement **cible** : le second
problème est absent du modèle de domaine. Sous le code actuel (pré-fix), ce
golden ne correspond pas à la sortie réelle de `joinProblems` (qui garde la
ligne avec host vide) — la régression est donc démontrée.
**Vérification :** lecture manuelle + simulation Node.js des fonctions pures
de `problems.js` (environnement sandbox sans Qt/Nix disponible ; `just ci`
réel à faire tourner par l'utilisateur, cf. phase0_results.md).
**Commit :** `test(model): reproduce disabled-trigger problem leaking through join (#8)`

#### Étape 2 : Fix query + model
**Description :** `triggerGetWithHosts()` passe `monitored: true` ; côté
Zabbix, un trigger désactivé (ou son host) n'est alors plus renvoyé. Côté
modèle, `joinProblems()` écarte (`filter`) tout problème dont le `triggerid`
n'a pas d'entrée dans `hostMap`, au lieu de l'afficher avec `host: ""`.
Golden `problems-multi` mis à jour pour refléter le nouveau comportement
(même scénario, résultat différent et intentionnel).
**Vérification :** idem étape 1 (simulation Node.js des 6 cas golden).
**Commit :** `fix(model): drop problems from inactive/missing triggers (#8)`

### Portes de qualité
- [ ] `just ci` passe — **non vérifiable dans cet environnement** (ni Nix, ni
      Qt/qmllint/qmlformat/qmltestrunner installés). Simulation Node.js des
      fonctions pures faite à la place ; `just ci` réel à confirmer par
      l'utilisateur avant merge.
- [x] Goldens à jour et intentionnels (diff relu, documenté ci-dessus)
- [x] Doc synchronisée (commentaires `problems.js`/`queries.js` mis à jour
      dans les mêmes commits)
- [x] Commits atomiques sur une branche dédiée (`fix/filter-disabled-trigger-problems`)
