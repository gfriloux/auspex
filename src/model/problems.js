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
