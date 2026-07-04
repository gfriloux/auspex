.pragma library

// Helpers de présentation. Purs et déterministes, consommés par la vue (v0.2.0) et
// testés inline (tst_model.qml). N'entrent PAS dans le modèle de domaine golden :
// `severityLabel` est dérivable de la sévérité, `relativeTime` dépend de « maintenant ».

var SEVERITY_LABELS = ["Not classified", "Information", "Warning", "Average", "High", "Disaster"];

function severityLabel(n) {
    return SEVERITY_LABELS[n] !== undefined ? SEVERITY_LABELS[n] : "Unknown";
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
