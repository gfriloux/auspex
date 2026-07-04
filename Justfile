default:
    @just --list

# Porte de qualité complète : format + lint + test. Seule source de vérité des gates.
ci: fmt-check lint test

# Formate le QML en place (qmlformat).
fmt:
    @find src -name '*.qml' -print0 2>/dev/null | xargs -0 -r qmlformat -i

# Vérifie le format sans modifier : échoue si un fichier n'est pas formaté.
fmt-check:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    while IFS= read -r -d '' f; do
        if ! diff -q "$f" <(qmlformat "$f") >/dev/null; then
            echo "non formaté : $f"; fail=1
        fi
    done < <(find src -name '*.qml' -print0 2>/dev/null)
    exit $fail

# Lint statique du QML (qmllint). Aucun warning toléré.
lint:
    @find src -name '*.qml' -print0 2>/dev/null | xargs -0 -r qmllint

# Tests golden : qmltestrunner exécute les transforms JS sur fixtures → compare aux goldens.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! find tests -name 'tst_*.qml' 2>/dev/null | grep -q .; then
        echo "aucun test (tests/tst_*.qml absent)"; exit 0
    fi
    # QtTest (TestCase) importe QtQuick.Window : on pointe explicitement le dossier qml de
    # qtdeclarative (sinon, en CI sans QML2_IMPORT_PATH ambiant, le module est introuvable).
    qmldir="$(dirname "$(dirname "$(command -v qmltestrunner)")")/lib/qt-6/qml"
    export QML2_IMPORT_PATH="$qmldir${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 qmltestrunner -input tests

# Régénère les goldens depuis les fixtures (transform courant). Relire le diff ensuite.
bless:
    QML_XHR_ALLOW_FILE_READ=1 quickshell -p bless.qml
