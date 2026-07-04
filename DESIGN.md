# DESIGN.md — auspex

> Ce document définit l'esprit, la structure et les **invariants** d'auspex.
> Avant d'ajouter quoi que ce soit, vérifie que ça s'inscrit ici. Si ce n'est pas
> le cas, la réponse est non.

---

## Ce qu'est auspex

auspex est un **widget de supervision Zabbix** pour la barre de bureau
**Quickshell / DankMaterialShell** (Material 3, thème Catppuccin Mocha). Une icône
dans la barre affiche un **badge d'état** (compteur de problèmes + couleur de la
sévérité la plus haute) ; au clic, un **popup cockpit** ancré sous l'icône liste les
problèmes actifs. auspex **notifie** à l'apparition d'un nouveau problème.

C'est un **Nagstamon repensé en plugin DMS natif, orienté Zabbix**. Là où le support
Zabbix de Nagstamon est « expérimental », auspex en fait un citoyen de première classe.

La source de vérité est l'**API JSON-RPC de Zabbix 7.0**. auspex ne parle qu'à cette
API, en **HTTP**, et **rien n'est à installer côté serveur** (contrairement à ZbxDsktp
qui pousse en UDP depuis un *media type*). Le rafraîchissement se fait par **polling**
(re-query périodique). En v1, auspex est en **lecture seule** : il lit l'état, il ne le
mute pas.

auspex est une **surface de supervision** au-dessus de Zabbix. Ce qu'on fait ensuite
d'un problème (ouvrir le host en SSH, ouvrir le graph dans le frontend) est de la
**configuration/délégation**, pas du design : ce document n'en détaille pas le rendu.

Ce n'est **pas** :

- Un serveur ni un agent Zabbix. auspex ne collecte pas de métriques, ne déclenche pas
  de triggers, ne remplace pas le frontend. Il **observe** l'état exposé par l'API.
- Un moteur d'alerting côté serveur. La détection des problèmes est le travail de
  Zabbix ; auspex reflète le résultat et prévient localement.
- Un client d'action (en v1). Acquitter / fermer / commenter un problème via l'API sont
  hors périmètre v1 — cap futur, cf. invariant *lecture seule (v1)* ci-dessous.

Aujourd'hui une seule instance Zabbix est configurée, mais rien dans le modèle ne le
suppose : voir l'invariant *agnostique à l'instance* ci-dessous.

---

## Le pipeline — trois étages

auspex est une transformation à trois étages. Chaque étage a un contrat clair et est
**indépendamment testable**. Rien ne traverse un étage qui ne devrait pas : la réponse
brute de l'API n'entre pas dans la vue, le QML ne construit jamais de requête JSON-RPC
lui-même.

```
  API Zabbix 7.0                                        popup Quickshell
      │                                                        ▲
      ▼                                                        │
  ┌────────┐        ┌─────────────┐        ┌──────────────────┐
  │ query  │  ───▶  │ model       │  ───▶  │ view             │
  │ (RPC)  │        │ (problèmes) │        │ (QML / Material) │
  └────────┘        └─────────────┘        └──────────────────┘
```

### 1. `query` — construction JSON-RPC

Construit les **corps de requêtes JSON-RPC** Zabbix (`problem.get`, `event.get`,
`trigger.get`, `host.get`…) — des fonctions **pures** : `method` + `params`, **sans
aucun secret**. Ne connaît ni le réseau ni la présentation. L'exécution HTTP est le
travail du **service** (`Zabbix.qml`), pas de cette couche.

> **L'auth vit dans un header, pas dans le corps.** Zabbix 7.0 déprécie le paramètre
> `auth` du corps JSON-RPC : l'authentification passe par le header HTTP
> `Authorization: Bearer <token>`, injecté par le service. Conséquence directe : les
> corps construits par `query` (et donc les **fixtures golden**) ne contiennent jamais
> de token — committables sans risque.

### 2. `model` — modèle de domaine

Transforme les réponses Zabbix en **modèle de problèmes** : host, nom du trigger,
sévérité (0–5), ancienneté (depuis `clock`), état d'acquittement, suppression. Tient
l'état applicatif : `problems` (liste courante), `worstSeverity`, `counts` (par
sévérité), `connectionStatus`, `lastPollAt`, et le **delta** entre deux polls (nouveaux
problèmes / problèmes résolus) qui alimente les notifications. **Pur et testable** :
mêmes réponses Zabbix → même modèle (cf. golden tests, PROCEDURE_PLANS.md).

### 3. `view` — rendu Quickshell

QML / Qt Quick. Consomme le modèle, ne construit ni n'exécute jamais de requête en
direct. Porte le système visuel ci-dessous, en réutilisant les composants Material 3 de
DankMaterialShell.

### Implémentation

auspex est un **plugin DankMaterialShell** (`plugin.json` à la racine + `src/`),
installé dans `~/.config/DankMaterialShell/plugins/Auspex/`. Il hérite du thème
(Catppuccin Mocha) et des composants Material 3 de DMS.

- `query` → `src/query/queries.js` : builders de corps JSON-RPC (`problem.get`,
  `trigger.get`, `host.get`…), fonctions pures. Exécutés par `src/view/Zabbix.qml`
  (service : HTTP `POST` vers `api_jsonrpc.php`, header `Authorization: Bearer`, gestion
  d'erreur/timeout).
- `model` → `src/model/problems.js` (`parseProblems`, `parseTriggers` = map
  triggerid→host, `joinProblems`, `worstSeverity`, `countsBySeverity`, `diffProblems`
  pour le delta) + `format.js` (`relativeTime`, `severityLabel`) — ces helpers de
  présentation restent **hors du modèle golden** (dérivables / dépendants de « maintenant »).
  Pur, testé par goldens + inline (`tests/`, `just test` / `just bless`).
- `view` → `src/view/` : `AuspexWidget` (barre + badge), `Cockpit` (popout : en-tête
  état de connexion, liste des problèmes, filtres sévérité, états vide/erreur/chargement),
  `Settings` (config : URL de l'instance, token, intervalle de poll, filtres). Thème = DMS.

---

## Invariants du domaine

1. **L'API Zabbix fait foi ; rien côté serveur.** Toute donnée affichée vient de l'API
   JSON-RPC (pas de cache parallèle persistant). auspex n'exige **aucune** configuration
   côté serveur Zabbix (pas de *media type*, pas de script d'alerte) : un simple accès
   API suffit.
2. **Lecture seule (v1).** auspex lit l'état (`*.get`), il ne le mute pas. Acquitter,
   fermer, commenter (`event.acknowledge`) sont **hors périmètre v1** — un cap futur qui
   ne doit pas être peint dans un coin, mais qui n'est pas construit. Toute écriture sera
   un PLAN dédié.
3. **Cible Zabbix 7.0, auth Bearer, utilisateur read-only.** Endpoint
   `POST <url>/api_jsonrpc.php`, `Content-Type: application/json`, `jsonrpc: "2.0"`.
   Authentification par **API token** (header `Authorization: Bearer`), rattaché à un
   utilisateur Zabbix en **rôle lecture seule**. Le token est un secret : il vit dans la
   config/le service, **jamais** dans les couches `query`/`model` ni dans les fixtures.
4. **Le problème est l'unité, pas l'événement brut.** Le modèle raisonne en **problèmes
   actifs** (`problem.get`) : un host, un trigger, une sévérité, une ancienneté, un état
   d'ack. L'événement brut Zabbix est un détail de la couche `query`, pas du domaine.
5. **Mapping de sévérité figé.** Les sévérités Zabbix 0–5 (*not classified, information,
   warning, average, high, disaster*) pilotent couleur et tri. Le mapping vers la palette
   est un invariant visuel (ci-dessous). La couleur du badge = **sévérité active la plus
   haute**.
6. **Agnostique à l'instance.** auspex ne modélise pas les instances comme des entités de
   premier plan : une instance Zabbix n'est qu'une **facette** (URL + token + filtres).
   Mono ou multi-instance se modélisent sans traitement spécial — une future vue
   multi-instance (badges séparés, agrégation) sera un PLAN si le besoin émerge.
7. **Best-effort sur la connexion.** L'état de connexion (`live | polling | error |
   unauthorized`) est *observé*. Une API indisponible, lente ou un token invalide
   **dégrade l'affichage** (dernier état connu + bandeau d'erreur), ne fait **jamais**
   planter le widget.
8. **Déterminisme de la couche données.** `query` + `model` sont déterministes pour un
   jeu de réponses Zabbix figé — c'est ce qui rend les golden tests possibles. Le delta
   (nouveaux/résolus) est une fonction pure de (état précédent, état courant).

---

## Système visuel

Hérité de DankMaterialShell (Material 3, Catppuccin Mocha) et aligné sur astropath. Les
**valeurs durables** (palette, mapping de sévérité, typo, formes) sont figées ci-dessous.

> **La direction visuelle du cockpit (layout pixel-perfect) n'est pas encore figée.**
> Elle sera arrêtée par un **handoff design** (claude design) mené *après* v0.1.0, une
> fois la forme du modèle gelée par les goldens — car la maquette doit afficher les
> champs réels d'un problème. Le prototype HTML retenu vivra dans
> `tmp/design_handoff_auspex/` (non commité) et ses valeurs durables seront recopiées
> dans cette section. Cf. le séquencement dans PROCEDURE_PLANS.md.

### Palette — Catppuccin Mocha

| Rôle | Hex |
|---|---|
| Fond / base | `#1e1e2e` |
| Mantle | `#181825` |
| Crust | `#11111b` |
| Conteneur surélevé | `#313244` |
| Conteneur le plus haut | `#45475a` |
| Outline / séparateurs | `#6c7086` |
| Texte | `#cdd6f4` |
| Texte secondaire | `#a6adc8` |
| **Accent primaire — Mauve** | `#cba6f7` |
| Accent secondaire — Lavender | `#b4befe` |
| Succès / RAS / live — Green | `#a6e3a1` |
| Info — Blue | `#89b4fa` |
| Warning — Yellow | `#f9e2af` |
| Average — Peach | `#fab387` |
| High — Maroon | `#eba0ac` |
| Disaster / erreur — Red | `#f38ba8` |
| Accent froid — Teal | `#94e2d5` |

Mauve **avec parcimonie** : focus, sélection, éléments actifs. Jamais en aplat massif.

### Mapping couleur des sévérités (impératif)

Le pilier visuel d'auspex. Escalade monotone du calme (vert) au critique (rouge) :

| # | Sévérité Zabbix | Couleur | Hex |
|---|---|---|---|
| — | *aucun problème (RAS)* | Green | `#a6e3a1` |
| 0 | Not classified | Overlay | `#6c7086` |
| 1 | Information | Blue | `#89b4fa` |
| 2 | Warning | Yellow | `#f9e2af` |
| 3 | Average | Peach | `#fab387` |
| 4 | High | Maroon | `#eba0ac` |
| 5 | Disaster | Red | `#f38ba8` |

Le **badge de la barre** prend la couleur de la sévérité active la plus haute (vert si
aucun problème). Chip de sévérité dans la liste = `background: rgba(couleur, 0.16)` +
`color: couleur`.

### Formes & profondeur

- Rayon principal **12px** (cartes, popup) ; 6–10px pour chips/petits boutons ; 14px barre.
- Profondeur par **empilement de surfaces**, pas d'ombres dures. Seule ombre :
  `0 16px 48px rgba(0,0,0,.5)` sous le popup. Blur de fond : `blur(18px)`.
- **Séparateurs de liste** : filet 1px en **dégradé** (fondu aux deux bords), teinte
  `outline`. S'efface autour de la ligne active/survolée pour ne jamais la trancher.
- Typo : **Inter** (UI), **JetBrains Mono** (compteurs/heures/host), **Material Symbols
  Rounded** (icônes, fill 0).

---

## Clin d'œil Adeptus Mechanicus

Subtil, jamais kitsch. Un *auspex* est le scanner de détection de menaces du 40k :
vocabulaire « balayage / signal / contact », un seul cog dans l'en-tête, état vide
« Aucun signal hostile. ». C'est un assaisonnement, pas un thème.
