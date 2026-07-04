.pragma library
.import "../src/model/problems.js" as Model

// Registre unique des cas golden, consommé par tst_golden.qml ET bless.qml.
// Chaque cas : { name, transform } avec fixtures/<name>.json → golden/<name>.json.

// Pipeline problème→host complet : la fixture porte les deux réponses (problem.get +
// trigger.get) ; le golden est le modèle de domaine joint.
function joinCase(input) {
    var problems = Model.parseProblems(input.problems);
    var hosts = Model.parseTriggers(input.triggers);
    return Model.joinProblems(problems, hosts);
}

var cases = [
    {
        "name": "problems-empty",
        "transform": joinCase
    },
    {
        "name": "problems-single",
        "transform": joinCase
    },
    {
        "name": "problems-multi",
        "transform": joinCase
    }
];
