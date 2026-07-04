.pragma library

// Builders de corps JSON-RPC pour l'API Zabbix 7.0. Fonctions PURES : elles ne
// construisent que le corps (`method` + `params`), sans réseau ni authentification.
//
// L'auth vit dans le header HTTP `Authorization: Bearer <token>`, injecté par le
// service (src/view/Zabbix.qml, v0.2.0) : le paramètre `auth` du corps est déprécié en
// 7.0 et n'apparaît JAMAIS ici. Corollaire : aucun secret dans ces corps, donc les
// fixtures/goldens dérivés sont committables sans risque (cf. DESIGN.md).

// Enveloppe JSON-RPC 2.0 commune. `id` corrèle requête/réponse côté service ; par
// défaut 1 (chaque POST est indépendant), surchargée si besoin.
function envelope(method, params, id) {
    return {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": (id === undefined ? 1 : id)
    };
}

// problem.get — problèmes actifs. Tri déterministe (eventid DESC) requis pour des
// comparaisons stables. `recent:false` = uniquement les problèmes non résolus.
// opts.severities (tableau 0-5) filtre optionnellement ; opts.id surcharge l'id.
function problemGet(opts) {
    opts = opts || {};
    var params = {
        "output": ["eventid", "objectid", "name", "severity", "clock", "r_eventid", "acknowledged", "suppressed"],
        "recent": false,
        "sortfield": "eventid",
        "sortorder": "DESC"
    };
    if (opts.severities && opts.severities.length)
        params.severities = opts.severities;
    return envelope("problem.get", params, opts.id);
}

// trigger.get — résout le host d'un problème. problem.get ne joint pas le host
// (pas de selectHosts) : on récupère les objectid (= triggerids) des problèmes puis on
// demande leurs hosts ici. La jointure triggerid→host se fait dans le model.
function triggerGetWithHosts(triggerids, opts) {
    opts = opts || {};
    var params = {
        "output": ["triggerid"],
        "selectHosts": ["hostid", "name"],
        "triggerids": triggerids
    };
    return envelope("trigger.get", params, opts.id);
}
