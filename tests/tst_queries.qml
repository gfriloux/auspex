import QtQuick
import QtTest
import "../src/query/queries.js" as Q
import "lib/golden.js" as Golden

TestCase {
    name: "queries"

    function eq(actual, expected) {
        verify(Golden.equal(actual, expected), "attendu " + Golden.pretty(expected) + "\nobtenu " + Golden.pretty(actual));
    }

    function test_problemGet_default() {
        eq(Q.problemGet(), {
            "jsonrpc": "2.0",
            "method": "problem.get",
            "params": {
                "output": ["eventid", "objectid", "name", "severity", "clock", "r_eventid", "acknowledged", "suppressed"],
                "recent": false,
                "sortfield": "eventid",
                "sortorder": "DESC"
            },
            "id": 1
        });
    }

    function test_problemGet_severities() {
        var body = Q.problemGet({
            "severities": [4, 5]
        });
        eq(body.params.severities, [4, 5]);
        compare(body.method, "problem.get");
    }

    // Un filtre de sévérité vide ne doit PAS ajouter la clé (sinon Zabbix renvoie vide).
    function test_problemGet_emptySeverities() {
        var body = Q.problemGet({
            "severities": []
        });
        verify(body.params.severities === undefined);
    }

    function test_problemGet_customId() {
        compare(Q.problemGet({
            "id": 7
        }).id, 7);
    }

    function test_triggerGetWithHosts() {
        eq(Q.triggerGetWithHosts(["101", "102"]), {
            "jsonrpc": "2.0",
            "method": "trigger.get",
            "params": {
                "output": ["triggerid"],
                "selectHosts": ["hostid", "name"],
                "triggerids": ["101", "102"]
            },
            "id": 1
        });
    }
}
