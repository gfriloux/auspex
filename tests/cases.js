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

// Delta : la fixture porte deux états successifs (prev/curr, déjà en modèle de domaine) ;
// le golden est { added, resolved }.
function deltaCase(input) {
    return Model.diffProblems(input.prev, input.curr);
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
    },
    {
        "name": "delta-appeared",
        "transform": deltaCase
    },
    {
        "name": "delta-resolved",
        "transform": deltaCase
    },
    {
        "name": "delta-mixed",
        "transform": deltaCase
    }
];
