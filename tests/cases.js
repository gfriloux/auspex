.pragma library

// Registre unique des cas golden, consommé par tst_golden.qml ET bless.qml.
// Chaque cas : { name, transform } avec fixtures/<name>.json → golden/<name>.json.
// Vide pour l'instant : rempli par les étapes query (corps JSON-RPC) et model
// (parsing / jointure / agrégats / delta).
var cases = [];
