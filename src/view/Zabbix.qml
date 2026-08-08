// Service Zabbix : poll l'API JSON-RPC 7.0 en XMLHttpRequest, transforme avec la couche
// données (query/model), expose le modèle + un statut de connexion. Lecture seule.
//
// Deux appels enchaînés : problem.get → (triggerids) → trigger.get(selectHosts), puis
// jointure problème→host dans le model. L'auth (Bearer) et le Content-Type sont posés en
// headers de la requête : le token ne quitte jamais le processus DMS.
//
// Deux limites du runtime QML dictent la forme de ce fichier :
//   - `xhr.timeout` n'existe pas (XHR niveau 1) → le délai est tenu par `timeoutTimer`,
//     qui abandonne la requête en cours (`abort()`).
//   - un échec réseau ne remonte qu'un `status = 0`, sans cause → le libellé est dérivé du
//     schéma de l'URL (cf. `Format.networkErrorMessage`), pas d'un diagnostic qu'on n'a pas.
import QtQuick
import "../query/queries.js" as Queries
import "../model/problems.js" as Model
import "../model/format.js" as Format

QtObject {
    id: root

    // --- Config (injectée par le widget depuis pluginData) ---
    property string url: ""
    property string token: ""
    property int intervalMs: 30000
    property int timeoutMs: 10000 // abandon d'une requête sans réponse
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

    // Émis quand des problèmes NOUVEAUX apparaissent (delta `added`), jamais au 1er poll.
    // La vue consomme ce signal pour notifier / pulser (le service ne fait aucun effet de bord).
    signal problemsAppeared(var added)

    // Problèmes partiels (avec triggerid) entre le 1er et le 2e appel.
    property var _partial: []
    property bool _busy: false

    // Requête en vol. Sert aussi de jeton d'identité : une requête abandonnée est mise à
    // null ici, ce qui fait ignorer sa réponse tardive.
    property var _xhr: null

    // État précédent + drapeau de baseline pour le delta (cf. _commit).
    property var _prevProblems: []
    property bool _hasBaseline: false

    // (Re)poll quand un réglage change.
    function reconfigure() {
        if (!root.configured) {
            root.connectionStatus = "idle";
            return;
        }
        poll();
    }
    onUrlChanged: reconfigure()
    onTokenChanged: reconfigure()

    // ---- Poll ----

    // POST JSON-RPC. `onOk` reçoit le corps de la réponse ; tout échec aboutit à `_fail`.
    function _post(body, onOk) {
        var xhr = new XMLHttpRequest();
        root._xhr = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (root._xhr !== xhr)
                return; // requête abandonnée entre-temps : sa réponse ne vaut plus rien
            root._xhr = null;
            root.timeoutTimer.stop();
            if (xhr.status === 200) {
                onOk(xhr.responseText);
                return;
            }
            root._fail(Format.networkErrorMessage(xhr.status === 0 ? "unreachable" : "http", root.url, xhr.status));
        };
        try {
            xhr.open("POST", root.url);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("Authorization", "Bearer " + root.token);
            root.timeoutTimer.restart();
            xhr.send(JSON.stringify(body));
        } catch (e) {
            root._xhr = null;
            root.timeoutTimer.stop();
            root._fail("URL de l'API invalide");
        }
    }

    // Faute de `xhr.timeout` dans le runtime QML, c'est ce Timer qui borne l'attente. Il
    // décide de l'échec lui-même (plutôt que de s'en remettre au DONE provoqué par abort) :
    // le service ne peut pas rester coincé en `_busy` si l'abandon ne rappelle personne.
    property Timer timeoutTimer: Timer {
        interval: root.timeoutMs
        repeat: false
        onTriggered: {
            if (!root._xhr)
                return;
            var pending = root._xhr;
            root._xhr = null;
            pending.abort();
            root._fail(Format.networkErrorMessage("timeout", root.url, 0));
        }
    }

    function poll() {
        if (!root.configured || root._busy)
            return;
        root._busy = true;
        root.connectionStatus = "polling";
        root._post(Queries.problemGet({
            "severities": root.severities
        }), root._onProblems);
    }

    // 1er appel : problem.get.
    function _onProblems(text) {
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
        root._post(Queries.triggerGetWithHosts(triggerids), root._onTriggers);
    }

    // 2e appel : trigger.get(selectHosts) → jointure.
    function _onTriggers(text) {
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
        // Delta sur l'état réel précédent (un _fail ne réinitialise pas la baseline).
        var diff = Model.diffProblems(root._prevProblems, list);
        root._prevProblems = list;

        root.problems = list;
        root.worstSeverity = Model.worstSeverity(list);
        root.counts = Model.countsBySeverity(list);
        root.connectionStatus = "live";
        root.errorMessage = "";
        root.lastPollAt = Date.now();
        root._busy = false;

        // Le 1er commit réussi établit la baseline SANS notifier (sinon salve au démarrage) ;
        // ensuite seulement, tout `added` prévient. `eventid` garantit zéro re-notification.
        if (root._hasBaseline && diff.added.length > 0)
            root.problemsAppeared(diff.added);
        root._hasBaseline = true;
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
        triggeredOnStart: true // premier poll immédiat, sans attendre l'intervalle
        onTriggered: root.poll()
    }

    Component.onCompleted: reconfigure()
}
