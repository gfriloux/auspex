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
}
