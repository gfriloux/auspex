# Tests manuels — v0.3.0 (cockpit direction C complet)

La couche données reste golden-testée (`just ci`). v0.3.0 est **purement visuel** (étage
`view`) : rien d'automatisable ici. À dérouler dans l'instance de dev, sans serveur Zabbix
ni home-manager.

## Environnement de dev

Deux terminaux dans le dev shell (`nix develop`) :

```bash
just mock            # mock d'API Zabbix (scenario ok) sur :8384
#   scénarios : just mock empty | just mock unauthorized | just mock error
just dev-bar         # instance DMS isolée chargeant le worktree comme « Auspex (dev) »
```

Activer « Auspex (dev) », URL `http://127.0.0.1:8384/api_jsonrpc.php`, token quelconque.
Le mock `ok` sert des hôtes longs + sévérités variées (preview d'alignement réaliste).

## Extraction Cockpit (étape 1) — iso-visuel

- [ ] Après extraction dans `Cockpit.qml`, le popout s'ouvre **identique à v0.2.0** (mêmes
      colonnes, même liste, même état vide). Aucune régression, pas de fenêtre 0×0.

## En-tête télémétrie (étape 2)

- [ ] Cog `radar` Mauve + wordmark `AUSPEX` (mono, espacé) + `// telemetry` discret.
- [ ] À droite : point d'état + libellé. `ok` → `LIVE` (point vert) ; pendant un poll →
      `interrogation…` ; erreur → état dégradé.
- [ ] Bouton refresh : **tourne** pendant le poll ; un clic déclenche un poll immédiat.

## Barre de résumé segmentée (étape 3)

- [ ] Grand compteur total = nombre de problèmes.
- [ ] Barre 12px segmentée : un segment par sévérité présente, largeur proportionnelle au
      compte, couleur = sévérité. Somme visuelle cohérente avec le total.
- [ ] Transition douce de largeur quand un problème apparaît/se résout (rejouer le mock).
- [ ] Scénario `empty` : barre verte pleine discrète (RAS), compteur 0.

## Légende cliquable = filtre côté vue (étape 4)

- [ ] Une entrée par sévérité (carré couleur + label + compteur) ; entrée à compte nul
      atténuée (opacité 0.4).
- [ ] Clic sur une sévérité → ses lignes **disparaissent** de la liste ; re-clic → réapparaissent.
- [ ] Le filtre n'affecte **pas** la barre de résumé (elle reste sur les counts réels) ni le
      badge de barre.
- [ ] Tri sévérité↓ puis âge conservé après filtrage.

## Lignes enrichies (étape 5)

- [ ] Point de sévérité 9px + halo en tête de ligne, couleur = sévérité.
- [ ] Icône `task_alt` sur une ligne acquittée, `notifications_off` sur une supprimée ;
      texte atténué `#7f849c` sur ces lignes.
- [ ] Séparateur 1px en dégradé ; au survol d'une ligne il **ne la tranche pas**.
- [ ] Aucun quick-link au survol (reporté hors v0.3.0) — vérifier l'absence.

## États (étape 6)

- [ ] **Chargement** (1er poll, aucun état connu) : skeleton shimmer (barre + lignes grises).
- [ ] **Erreur** (`just mock error` ou URL injoignable) : bandeau rouge + icône `error` +
      **dernier état connu conservé** dessous + bouton **Réessayer** qui relance un poll.
- [ ] **Unauthorized** (`just mock unauthorized`) : bandeau + icône `lock` + « Vérifier
      l'API token (read-only) ».
- [ ] **Vide/zen** (`just mock empty`) : icône `shield`, « Aucun signal hostile. » +
      sous-texte « Tous les systèmes nominaux. Balayage actif… ».

## Pied de cadence (étape 7)

- [ ] Rappel des appels `problem.get · trigger.get`.
- [ ] `last poll N s · next in N s` : « next in » décroît, « last poll » se réinitialise à
      chaque poll.

## Reporté (hors v0.3.0)

- Quick-links de délégation (SSH host / frontend Zabbix / graph) → plan dédié ultérieur.
- Notifications desktop + pulse « nouveau problème » (delta `added`) → v0.4.0.
