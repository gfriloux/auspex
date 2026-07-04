.pragma library

// Transforms du modèle de problèmes. Fonctions PURES : mêmes réponses Zabbix → même
// modèle de domaine (cf. golden tests). Entrée = réponse JSON-RPC déjà parsée ; sortie =
// modèle auspex. Zabbix renvoie tous les scalaires en chaînes : la normalisation
// (int / bool) est faite ici, une bonne fois.

function bool(s) {
    return s === "1" || s === 1 || s === true;
}

// Réponse problem.get → problèmes partiels (sans host, à joindre). Conserve l'ordre
// renvoyé par Zabbix (tri déterministe côté query). objectid = triggerid.
function parseProblems(res) {
    var rows = (res && res.result) || [];
    return rows.map(function (p) {
        return {
            "eventid": p.eventid,
            "triggerid": p.objectid,
            "trigger": p.name,
            "severity": parseInt(p.severity, 10),
            "since": parseInt(p.clock, 10),
            "acknowledged": bool(p.acknowledged),
            "suppressed": bool(p.suppressed)
        };
    });
}

// Réponse trigger.get (selectHosts) → map triggerid → nom de host (1er host, "" sinon).
function parseTriggers(res) {
    var rows = (res && res.result) || [];
    var map = {};
    for (var i = 0; i < rows.length; i++) {
        var t = rows[i];
        map[t.triggerid] = (t.hosts && t.hosts.length) ? t.hosts[0].name : "";
    }
    return map;
}

// Joint les problèmes partiels avec la map de hosts → modèle de domaine final.
// triggerid absent de la map → host "" (best-effort : ne casse jamais l'affichage).
function joinProblems(problems, hostMap) {
    return problems.map(function (p) {
        return {
            "eventid": p.eventid,
            "host": hostMap[p.triggerid] !== undefined ? hostMap[p.triggerid] : "",
            "trigger": p.trigger,
            "severity": p.severity,
            "since": p.since,
            "acknowledged": p.acknowledged,
            "suppressed": p.suppressed
        };
    });
}

// Sévérité active la plus haute → couleur du badge. -1 si aucun problème (RAS/vert).
function worstSeverity(problems) {
    var w = -1;
    for (var i = 0; i < problems.length; i++)
        if (problems[i].severity > w)
            w = problems[i].severity;
    return w;
}

// Compteur par niveau de sévérité. Les 6 clés (0-5) sont toujours présentes (0 inclus)
// pour un rendu déterministe.
function countsBySeverity(problems) {
    var c = {
        "0": 0,
        "1": 0,
        "2": 0,
        "3": 0,
        "4": 0,
        "5": 0
    };
    for (var i = 0; i < problems.length; i++) {
        var s = problems[i].severity;
        if (c[s] !== undefined)
            c[s] += 1;
    }
    return c;
}

// Delta entre deux états (par eventid) → { added, resolved }. Fonction PURE de
// (état précédent, état courant) : base des notifications (v0.2.0), testée sans notif.
// `added` = présents dans curr mais pas prev ; `resolved` = présents dans prev mais pas
// curr. L'ordre de chaque liste suit sa source.
function diffProblems(prev, curr) {
    var prevIds = {}, currIds = {}, i;
    for (i = 0; i < prev.length; i++)
        prevIds[prev[i].eventid] = true;
    for (i = 0; i < curr.length; i++)
        currIds[curr[i].eventid] = true;
    return {
        "added": curr.filter(function (p) {
            return !prevIds[p.eventid];
        }),
        "resolved": prev.filter(function (p) {
            return !currIds[p.eventid];
        })
    };
}
