.pragma library

// Helpers de présentation. Purs et déterministes, consommés par la vue (v0.2.0) et
// testés inline (tst_model.qml). N'entrent PAS dans le modèle de domaine golden :
// `severityLabel` est dérivable de la sévérité, `relativeTime` dépend de « maintenant ».

var SEVERITY_LABELS = ["Not classified", "Information", "Warning", "Average", "High", "Disaster"];

// Mapping sévérité → couleur (DESIGN.md, impératif). Escalade monotone.
var SEVERITY_COLORS = ["#6c7086", "#89b4fa", "#f9e2af", "#fab387", "#eba0ac", "#f38ba8"];
var RAS_COLOR = "#a6e3a1"; // Green — aucun problème / worstSeverity = -1.

function severityLabel(n) {
    return SEVERITY_LABELS[n] !== undefined ? SEVERITY_LABELS[n] : "Unknown";
}

// Couleur d'une sévérité 0-5 ; RAS (-1 ou hors plage) → vert. Pilote le badge de barre
// (severityColor(worstSeverity)) et les chips/accents.
function severityColor(n) {
    return SEVERITY_COLORS[n] !== undefined ? SEVERITY_COLORS[n] : RAS_COLOR;
}

// État de connexion (Zabbix.connectionStatus) → libellé + couleur du point de l'en-tête
// télémétrie. `idle` = pas encore interrogé ; `error`/`unauthorized` = dégradé (best-effort,
// invariant 7). Purs et dérivables → hors modèle golden.
var CONNECTION = {
    "live": {
        label: "LIVE",
        color: "#a6e3a1"
    } // Green
    ,
    "polling": {
        label: "interrogation…",
        color: "#89b4fa"
    } // Blue
    ,
    "error": {
        label: "hors ligne",
        color: "#f38ba8"
    } // Red
    ,
    "unauthorized": {
        label: "non autorisé",
        color: "#eba0ac"
    } // Maroon
    ,
    "idle": {
        label: "en veille",
        color: "#6c7086"
    } // Overlay
};

function connectionLabel(status) {
    return CONNECTION[status] !== undefined ? CONNECTION[status].label : "—";
}

function connectionColor(status) {
    return CONNECTION[status] !== undefined ? CONNECTION[status].color : "#6c7086";
}

// clock Zabbix = epoch en SECONDES ; now = millisecondes (Date.now()).
function relativeTime(clockSeconds, nowMs) {
    if (!clockSeconds)
        return "";
    var deltaMs = nowMs - clockSeconds * 1000;
    if (deltaMs < 0)
        deltaMs = 0;
    var min = Math.floor(deltaMs / 60000);
    if (min < 1)
        return "à l'instant";
    if (min < 60)
        return "il y a " + min + " min";
    var h = Math.floor(min / 60);
    if (h < 24)
        return "il y a " + h + " h";
    var d = Math.floor(h / 24);
    return "il y a " + d + " j";
}

// Contenu d'une notification desktop pour un lot de problèmes nouvellement apparus (delta
// `added`). Le lot est supposé déjà filtré par le seuil de sévérité (côté vue). Pur (dépend
// de `nowMs` pour l'âge) → hors modèle golden.
//   - 1 seul : titre « host · trigger », corps « Sévérité · âge ».
//   - plusieurs : titre « N nouveaux problèmes », corps « k Sévérité » décroissant, non nuls.
function notificationContent(added, nowMs) {
    if (!added || added.length === 0)
        return {
            "title": "",
            "body": ""
        };
    if (added.length === 1) {
        var p = added[0];
        return {
            "title": p.host + " · " + p.trigger,
            "body": severityLabel(p.severity) + " · " + relativeTime(p.since, nowMs)
        };
    }
    var counts = [0, 0, 0, 0, 0, 0];
    for (var i = 0; i < added.length; i++) {
        var s = added[i].severity;
        if (s >= 0 && s <= 5)
            counts[s]++;
    }
    var parts = [];
    for (var lvl = 5; lvl >= 0; lvl--) {
        if (counts[lvl] > 0)
            parts.push(counts[lvl] + " " + severityLabel(lvl));
    }
    return {
        "title": added.length + " nouveaux problèmes",
        "body": parts.join(" · ")
    };
}

// Urgence notify-send : « critical » si un problème du lot est High (4) ou Disaster (5),
// sinon « normal ». Pur.
function notificationUrgency(added) {
    if (!added)
        return "normal";
    for (var i = 0; i < added.length; i++) {
        if (added[i].severity >= 4)
            return "critical";
    }
    return "normal";
}

// URL de base du frontend Zabbix, dérivée de l'URL d'API : retire le suffixe
// /api_jsonrpc.php (et un éventuel / final). Pur. Alimente le placeholder {base}.
function frontendBase(apiUrl) {
    if (!apiUrl)
        return "";
    var base = String(apiUrl).replace(/\/api_jsonrpc\.php\/?$/, "");
    return base.replace(/\/$/, "");
}

// Construit une URL de quick-link en substituant les placeholders d'un template :
// {base} {hostid} {triggerid} {eventid}. Retourne "" si le template est vide OU si un
// placeholder référencé n'a pas de valeur (→ icône masquée côté vue). Pur.
function buildFrontendUrl(template, fields) {
    if (!template)
        return "";
    fields = fields || {};
    var keys = ["base", "hostid", "triggerid", "eventid"];
    var out = template;
    for (var i = 0; i < keys.length; i++) {
        var token = "{" + keys[i] + "}";
        if (out.indexOf(token) !== -1) {
            var val = fields[keys[i]];
            if (val === undefined || val === null || val === "")
                return ""; // placeholder requis mais absent → pas de lien
            out = out.split(token).join(String(val));
        }
    }
    return out;
}
