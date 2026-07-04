// Service Zabbix : poll l'API JSON-RPC 7.0 via curl (Process), transforme avec la couche
// données (query/model), expose le modèle + un statut de connexion. Lecture seule.
//
// Deux appels enchaînés : problem.get → (triggerids) → trigger.get(selectHosts), puis
// jointure problème→host dans le model. L'auth (Bearer) vit dans un fichier de config curl
// écrit sous $XDG_RUNTIME_DIR (0700, propre à l'utilisateur) : le token ne passe JAMAIS en
// argv, donc reste invisible dans `ps` (cf. DESIGN inv. 3).
import QtQuick
import Quickshell
import Quickshell.Io
import "../query/queries.js" as Queries
import "../model/problems.js" as Model

QtObject {
    id: root

    // --- Config (injectée par le widget depuis pluginData) ---
    property string url: ""
    property string token: ""
    property bool insecure: false // certif auto-signé → curl -k
    property int intervalMs: 30000
    property var severities: [] // filtre optionnel (0-5) ; vide = toutes

    // --- Sortie (modèle de domaine) ---
    property var problems: []
    property int worstSeverity: -1
    property var counts: ({})
    // idle | polling | live | error | unauthorized
    property string connectionStatus: "idle"
    property string errorMessage: ""
    property double lastPollAt: 0

    readonly property bool configured: url.length > 0 && token.length > 0
    readonly property string cfgDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/auspex"
    readonly property string cfgPath: cfgDir + "/curl.cfg"

    // Problèmes partiels (avec triggerid) entre le 1er et le 2e appel.
    property var _partial: []
    property bool _busy: false

    // ---- Config curl (contient le token) ----

    function _cfgText() {
        var lines = ['url = "' + root.url + '"', 'header = "Content-Type: application/json"', 'header = "Authorization: Bearer ' + root.token + '"'];
        if (root.insecure)
            lines.push("insecure");
        return lines.join("\n") + "\n";
    }

    // (Ré)écrit la config puis relance un poll. Déclenché quand un réglage change.
    function reconfigure() {
        if (!root.configured) {
            root.connectionStatus = "idle";
            return;
        }
        mkdirProc.running = true;
    }
    onUrlChanged: reconfigure()
    onTokenChanged: reconfigure()
    onInsecureChanged: reconfigure()

    property Process mkdirProc: Process {
        command: ["mkdir", "-m", "700", "-p", root.cfgDir]
        running: false
        onExited: code => {
            if (code !== 0) {
                root._fail("Impossible de préparer " + root.cfgDir);
                return;
            }
            cfgFile.path = root.cfgPath;
            cfgFile.setText(root._cfgText());
            afterConfig.restart(); // laisse le fichier se poser avant curl
        }
    }
    property FileView cfgFile: FileView {}
    property Timer afterConfig: Timer {
        interval: 60
        repeat: false
        onTriggered: root.poll()
    }

    // ---- Poll ----

    function _curlCmd(body) {
        return ["curl", "-s", "--max-time", "10", "--config", root.cfgPath, "-d", JSON.stringify(body)];
    }

    function poll() {
        if (!root.configured || root._busy)
            return;
        root._busy = true;
        root.connectionStatus = "polling";
        probProc.command = root._curlCmd(Queries.problemGet({
            "severities": root.severities
        }));
        probProc.running = true;
    }

    // 1er appel : problem.get.
    property Process probProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onProblems(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("auspex curl:", text.trim())
        }
        onExited: code => {
            if (code !== 0)
                root._fail("Zabbix injoignable (curl " + code + ")");
        }
    }

    function _onProblems(text) {
        if (!text || !text.trim())
            return; // échec réseau → géré par onExited
        var res = root._parse(text);
        if (res === null)
            return;
        var err = Model.rpcError(res);
        if (err) {
            root._failRpc(err);
            return;
        }
        root._partial = Model.parseProblems(res);
        var ids = {};
        for (var i = 0; i < root._partial.length; i++)
            ids[root._partial[i].triggerid] = true;
        var triggerids = Object.keys(ids);
        if (triggerids.length === 0) {
            root._commit([]); // aucun problème : pas de 2e appel
            return;
        }
        trigProc.command = root._curlCmd(Queries.triggerGetWithHosts(triggerids));
        trigProc.running = true;
    }

    // 2e appel : trigger.get(selectHosts) → jointure.
    property Process trigProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onTriggers(text)
        }
        onExited: code => {
            if (code !== 0)
                root._fail("Zabbix injoignable (curl " + code + ")");
        }
    }

    function _onTriggers(text) {
        if (!text || !text.trim())
            return;
        var res = root._parse(text);
        if (res === null)
            return;
        var err = Model.rpcError(res);
        if (err) {
            root._failRpc(err);
            return;
        }
        var hostMap = Model.parseTriggers(res);
        root._commit(Model.joinProblems(root._partial, hostMap));
    }

    // ---- Aboutissement ----

    function _parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            root._fail("Réponse Zabbix illisible");
            return null;
        }
    }

    function _commit(list) {
        root.problems = list;
        root.worstSeverity = Model.worstSeverity(list);
        root.counts = Model.countsBySeverity(list);
        root.connectionStatus = "live";
        root.errorMessage = "";
        root.lastPollAt = Date.now();
        root._busy = false;
    }

    // Best-effort : on conserve le dernier `problems` connu (DESIGN inv. 7).
    function _fail(msg) {
        root.connectionStatus = "error";
        root.errorMessage = msg;
        root._busy = false;
    }
    function _failRpc(err) {
        root.connectionStatus = err.unauthorized ? "unauthorized" : "error";
        root.errorMessage = err.message;
        root._busy = false;
    }

    property Timer pollTimer: Timer {
        interval: root.intervalMs
        running: root.configured
        repeat: true
        onTriggered: root.poll()
    }

    Component.onCompleted: reconfigure()
}
