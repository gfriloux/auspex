import QtQuick
import QtTest
import "../src/model/problems.js" as Model
import "../src/model/format.js" as Format

TestCase {
    name: "model"

    function test_severityLabel() {
        compare(Format.severityLabel(0), "Not classified");
        compare(Format.severityLabel(4), "High");
        compare(Format.severityLabel(5), "Disaster");
        compare(Format.severityLabel(9), "Unknown");
    }

    function test_connectionLabel() {
        compare(Format.connectionLabel("live"), "LIVE");
        compare(Format.connectionLabel("polling"), "interrogation…");
        compare(Format.connectionLabel("unauthorized"), "non autorisé");
        compare(Format.connectionLabel("zzz"), "—"); // statut inconnu
    }

    function test_connectionColor() {
        compare(Format.connectionColor("live"), "#a6e3a1");
        compare(Format.connectionColor("error"), "#f38ba8");
        compare(Format.connectionColor("idle"), "#6c7086");
        compare(Format.connectionColor("zzz"), "#6c7086"); // repli
    }

    function test_relativeTime() {
        var now = 1700000000000; // ms
        compare(Format.relativeTime(0, now), "");
        compare(Format.relativeTime(1699999970, now), "à l'instant");
        compare(Format.relativeTime(1699999700, now), "il y a 5 min");
        compare(Format.relativeTime(1699989200, now), "il y a 3 h");
        compare(Format.relativeTime(1699827200, now), "il y a 2 j");
    }

    // Zabbix renvoie des chaînes : la normalisation int/bool doit avoir lieu.
    function test_parseProblems_normalizes() {
        var res = {
            "result": [{
                    "eventid": "9",
                    "objectid": "5",
                    "name": "X",
                    "severity": "3",
                    "clock": "1700000000",
                    "acknowledged": "1",
                    "suppressed": "0"
                }]
        };
        var p = Model.parseProblems(res);
        compare(p.length, 1);
        compare(p[0].severity, 3); // int
        compare(p[0].since, 1700000000); // int
        compare(p[0].triggerid, "5"); // id conservé en chaîne
        compare(p[0].acknowledged, true);
        compare(p[0].suppressed, false);
    }

    function test_parseTriggers_firstHostOrEmpty() {
        var res = {
            "result": [{
                    "triggerid": "5",
                    "hosts": [{
                            "hostid": "1",
                            "name": "web01"
                        }]
                }, {
                    "triggerid": "6",
                    "hosts": []
                }]
        };
        var m = Model.parseTriggers(res);
        compare(m["5"], "web01");
        compare(m["6"], "");
    }

    // Un triggerid inconnu de la map ne casse pas la jointure : host "".
    function test_joinProblems_missingHost() {
        var joined = Model.joinProblems([{
                    "eventid": "1",
                    "triggerid": "404",
                    "trigger": "T",
                    "severity": 2,
                    "since": 1,
                    "acknowledged": false,
                    "suppressed": false
                }], {});
        compare(joined[0].host, "");
    }

    function test_worstSeverity() {
        compare(Model.worstSeverity([]), -1); // RAS
        compare(Model.worstSeverity([{
                    "severity": 2
                }, {
                    "severity": 5
                }, {
                    "severity": 3
                }]), 5);
    }

    function test_countsBySeverity() {
        var c = Model.countsBySeverity([{
                    "severity": 5
                }, {
                    "severity": 5
                }, {
                    "severity": 2
                }]);
        compare(c["5"], 2);
        compare(c["2"], 1);
        compare(c["0"], 0); // les 6 niveaux toujours présents
        compare(c["4"], 0);
    }

    function test_diffProblems_noChange() {
        var a = [{
                "eventid": "1"
            }, {
                "eventid": "2"
            }];
        var d = Model.diffProblems(a, a);
        compare(d.added.length, 0);
        compare(d.resolved.length, 0);
    }

    function test_severityColor() {
        compare(Format.severityColor(5), "#f38ba8"); // Disaster
        compare(Format.severityColor(0), "#6c7086"); // Not classified
        compare(Format.severityColor(2), "#f9e2af"); // Warning
        compare(Format.severityColor(-1), "#a6e3a1"); // RAS → vert
        compare(Format.severityColor(9), "#a6e3a1"); // hors plage → vert
    }

    function test_rpcError() {
        compare(Model.rpcError({
            "result": []
        }), null);
        var g = Model.rpcError({
            "error": {
                "code": -32602,
                "message": "Invalid params.",
                "data": "Cannot read severities."
            }
        });
        verify(g.message.indexOf("Invalid params.") !== -1);
        compare(g.unauthorized, false);
        var a = Model.rpcError({
            "error": {
                "code": -32602,
                "message": "Not authorised.",
                "data": "Session terminated, re-login, please."
            }
        });
        compare(a.unauthorized, true);
    }
}
