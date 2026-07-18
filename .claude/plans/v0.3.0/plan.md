# Plan : v0.3.0 — cockpit direction C complet

**Type :** vue (+ helpers de présentation `format.js`, testés inline)
**Objectif :** transformer le popout « liste minimale » de v0.2.0 en le **cockpit
direction C** décrit dans `DESIGN.md` : en-tête télémétrie, barre de résumé segmentée
par sévérité, légende cliquable servant de filtre, liste enrichie, et états
soignés (vide / chargement / erreur / unauthorized) + pied de cadence.
**Pourquoi :** v0.2.0 a livré le badge + une liste tabulaire brute. DESIGN §« Direction
visuelle — C » est la cible figée ; v0.3.0 la réalise. Surface de **lecture seule** : aucune
action sortante mutante, aucun quick-link (cf. hors périmètre).
**Étage(s) :** `view` principalement ; `format.js` (helpers purs de présentation) au besoin,
testés inline (hors golden). **Aucun changement de `query`/`model`/golden.**

## Contexte & état du working tree

- v0.1.0 (données) et v0.2.0 (service + badge + popout liste) sont **mergés sur `main`**.
- Le service `Zabbix.qml` expose déjà tout le nécessaire : `problems`, `worstSeverity`,
  `counts` (objet par sévérité), `connectionStatus` (`idle|polling|live|error|unauthorized`),
  `errorMessage`, `lastPollAt`, `configured`, `intervalMs`, filtre `severities`, et `poll()`.
- `src/view/AuspexWidget.qml` porte aujourd'hui **à la fois** la pièce de barre et le popout
  inline (~236 lignes). Le cockpit grossit nettement → on l'**extrait** dans `Cockpit.qml`.
- `src/model/format.js` : `severityLabel`, `severityColor`, `relativeTime` (purs).

## Décisions techniques (validées avec l'utilisateur)

1. **Filtre sévérité = côté vue.** La légende cliquable masque/affiche les lignes
   localement (état `activeSeverities` dans `Cockpit`). Ne touche **pas** le service ni la
   couche déterministe ; le service continue de tout ramener. Réactif, zéro latence réseau.
2. **Quick-links de délégation = HORS PÉRIMÈTRE v0.3.0.** Les liens sortants (SSH host,
   frontend Zabbix, graph) demandent de la config externe (adresse par host, templates) et
   un vrai design d'intégration terminal ; prématuré. → plan dédié ultérieur. La ligne de
   liste **ne montre pas** de rangée de quick-links au survol en v0.3.0.
3. **Extraction `Cockpit.qml`.** Le popout devient un composant `src/view/Cockpit.qml`
   (sous-type `PopoutComponent`) prenant une propriété `service` (le `Zabbix` de
   `AuspexWidget`) + `owner` (pour `popoutHeight`). Sépare barre et cockpit, garde des
   fichiers lisibles.
4. **Helpers de présentation dans `format.js`** si besoin (ex. libellé d'état de connexion),
   purs, testés inline dans `tst_model.qml` — **jamais** dans le modèle golden.

## Périmètre

**In scope :** en-tête télémétrie, barre de résumé segmentée, légende-filtre, liste enrichie
(point sévérité + halo, icônes ack/supprimé, atténuation, séparateur dégradé), états
vide/chargement(skeleton)/erreur/unauthorized, pied de cadence. Extraction `Cockpit.qml`.

**Out of scope :** quick-links / actions sortantes (plan futur), toute écriture Zabbix
(ack/close — invariant lecture seule), notifications desktop (v0.4.0), multi-instance,
changement de `query`/`model`/golden.

## Fichiers touchés

- [ ] `src/view/Cockpit.qml` *(nouveau)* — le cockpit complet.
- [ ] `src/view/AuspexWidget.qml` — délègue le popout à `Cockpit`, garde la pièce de barre.
- [ ] `src/model/format.js` — helper(s) de présentation éventuel(s) (état connexion).
- [ ] `tests/tst_model.qml` — test(s) inline du/des helper(s) `format.js` ajouté(s).
- [ ] `.claude/plans/v0.3.0/manual_tests.md` — enrichi à chaque phase vue.
- [ ] `DESIGN.md` / `README.md` — MAJ d'état à la clôture (cockpit livré).

## Étapes atomiques (chacune = 1 commit, portes vertes seul)

### Étape 1 : Extraire le popout dans `Cockpit.qml` (iso-visuel)
**Description :** déplacer le contenu de `popoutContent` dans `src/view/Cockpit.qml`
(`PopoutComponent` avec propriétés `service` et `owner`). `AuspexWidget` instancie
`Cockpit { service: svc; owner: root }`. **Aucun changement visuel** ni de comportement.
**Vérification :** `just ci` vert ; `just run` → le popout s'ouvre identique à v0.2.0.
**Commit :** `refactor(view): extraire le cockpit dans son propre composant`

### Étape 2 : En-tête télémétrie
**Description :** remplacer le header/details basique par la ligne 1 DESIGN : cog `radar`
Mauve, wordmark `AUSPEX` (mono, 700, letter-spacing .16em), `// telemetry` discret ; à
droite **état de connexion** (point coloré selon `connectionStatus` + libellé `LIVE` /
`poll N s` / `interrogation…` / `hors ligne`) et **bouton refresh** (icône, `spin` pendant
`polling`, `onClicked: service.poll()`). Ajouter au besoin un helper `connectionLabel` dans
`format.js` (+ test inline).
**Vérification :** `just ci` ; visuel : en-tête conforme, refresh déclenche un poll, le point
change de couleur/état selon la connexion.
**Commit :** `feat(view): en-tête télémétrie du cockpit`
*(si helper : `feat(view): en-tête télémétrie du cockpit` inclut le test inline format.js)*

### Étape 3 : Barre de résumé segmentée par sévérité
**Description :** sous l'en-tête, grand **compteur total** (mono ~20px) + **barre segmentée**
12px : un segment par sévérité présente dans `service.counts`, largeur ∝ compte, couleur =
sévérité (`Format.severityColor`), transition de largeur douce (.5s). RAS → barre verte
pleine discrète. Signature de la direction C : l'état global se lit d'un regard.
**Vérification :** `just ci` ; visuel avec le mock multi-sévérités : segments proportionnels,
somme = total, transition à l'arrivée/résolution d'un problème.
**Commit :** `feat(view): barre de résumé segmentée par sévérité`

### Étape 4 : Légende cliquable = filtre côté vue
**Description :** sous la barre, une entrée par sévérité (carré 8px couleur + label +
compteur) ; opacité 0.4 si compte nul. État `activeSeverities` (Set/array dans `Cockpit`,
toutes actives par défaut). Clic sur une entrée → toggle ; la **liste** n'affiche que les
sévérités actives (filtre local, la barre de résumé reste sur les counts réels). Indicateur
visuel d'entrée désactivée (barrée/atténuée).
**Vérification :** `just ci` ; visuel : cliquer une sévérité masque ses lignes, re-cliquer les
ré-affiche ; l'ordre sévérité↓ puis âge reste respecté.
**Commit :** `feat(view): légende de sévérité cliquable (filtre côté vue)`

### Étape 5 : Enrichissement des lignes de la liste
**Description :** faire évoluer le delegate v0.2.0 vers DESIGN : **point de sévérité** 9px
(couleur = sévérité, halo `0 0 0 4px rgba(couleur,.16)`) en tête de ligne (remplace/complète
la barre latérale 3px), icônes d'état (`task_alt` si acquitté, `notifications_off` si
supprimé), atténuation texte `#7f849c` sur ligne ack/supprimée (déjà partiel → affiner),
**séparateur dégradé** 1px (fondu aux bords, teinte outline) qui s'efface au survol. Host /
trigger / chip sévérité / âge : conservés (colonnes alignées v0.2.0). **Pas** de quick-links.
**Vérification :** `just ci` ; visuel : point + halo, icônes ack/supprimé sur le mock,
survol n'entaille pas la ligne.
**Commit :** `feat(view): enrichir les lignes de problème (point, halo, icônes d'état)`

### Étape 6 : États chargement / erreur / unauthorized / vide
**Description :** brancher le corps du cockpit sur `connectionStatus` :
- **chargement** (1er poll, `polling` && aucun problème connu) : **skeleton** shimmer
  (barre de sévérité + lignes grises).
- **erreur** : bandeau rouge `rgba(243,139,168,.08)` bord `rgba(243,139,168,.3)`, icône
  `error`, message « Zabbix injoignable — dernier état connu affiché », bouton **Réessayer**
  (`service.poll()`).
- **unauthorized** : même bandeau, icône `lock`, « Vérifier l'API token (read-only) ».
- **vide/zen** : conserver, aligner le sous-texte DESIGN (« Tous les systèmes nominaux.
  Balayage actif… »).
Le dernier état connu (liste) reste visible sous le bandeau d'erreur (best-effort, invariant 7).
**Vérification :** `just ci` ; visuel via le mock : forcer chaque `connectionStatus`
(URL absente / token bidon / mock en erreur) et vérifier chaque rendu + bouton Réessayer.
**Commit :** `feat(view): états chargement, erreur et unauthorized du cockpit`

### Étape 7 : Pied de cadence
**Description :** pied bas du cockpit : rappel des appels (`problem.get · trigger.get`) et
cadence `last poll N s · next in N s` (dérivée de `lastPollAt` + `intervalMs`, rafraîchie par
le timer `now` déjà présent). Discret (`rgba(24,24,37,.55)`).
**Vérification :** `just ci` ; visuel : le compteur « next in » décroît, « last poll »
se réinitialise à chaque poll.
**Commit :** `feat(view): pied de cadence du cockpit`

### Étape 8 : Doc — cockpit v0.3.0 livré
**Description :** MAJ des mentions d'état : commentaire d'en-tête de `AuspexWidget.qml`
(retirer « le cockpit arrive en v0.3.0 »), `README.md` (statut des features), et note
DESIGN si un détail d'implémentation mérite d'être figé (le filtre côté vue, l'absence de
quick-links en v0.3.0). La doc de chaque comportement va **de préférence dans le commit de
sa phase** ; cette étape ne ramasse que l'état résiduel.
**Vérification :** relecture ; `just ci`.
**Commit :** `docs: cockpit direction C livré (v0.3.0)`

## Portes de qualité (clôture)

- [ ] `just ci` passe (fmt-check + lint exit 0 + test).
- [ ] Goldens **inchangés** (aucun diff — v0.3.0 ne touche pas la couche données).
- [ ] `manual_tests.md` exécuté : chaque état (live/vide/chargement/erreur/unauthorized) vu
      en vrai, filtre et refresh testés.
- [ ] Doc synchronisée (dans le commit concerné + étape 8).
- [ ] Commits atomiques sur `feat/v0.3.0-cockpit` ; **l'utilisateur** relit, merge, push.
