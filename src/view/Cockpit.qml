// Cockpit auspex — contenu du popout (extrait de AuspexWidget en v0.3.0).
// v0.3.0 construit ici la direction C : en-tête télémétrie, barre de résumé segmentée,
// légende-filtre, liste enrichie, états soignés, pied de cadence. Cette étape 1 est un
// portage iso-visuel de la liste minimale v0.2.0 ; les phases suivantes l'enrichissent.
//
// Découplé de AuspexWidget : reçoit le service `Zabbix` (`service`) et le composant de
// plugin racine (`owner`, pour `popoutHeight`). Ne construit ni n'exécute jamais de requête.
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../model/format.js" as Format

PopoutComponent {
    id: cockpit

    // Service de données (instance Zabbix) et composant racine (barre) injectés par le parent.
    property var service
    property var owner

    readonly property int problemCount: service ? service.problems.length : 0

    // Horloge pour rafraîchir « il y a N min ».
    property double now: Date.now()

    // Largeur de la colonne host = celle du nom le plus long (auto-fit), bornée.
    // Même valeur pour toutes les lignes → alignement, sans gaspiller d'espace.
    TextMetrics {
        id: hostMetrics
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
    }
    readonly property real hostColWidth: {
        let w = 0;
        for (let i = 0; i < service.problems.length; i++) {
            hostMetrics.text = service.problems[i].host;
            if (hostMetrics.advanceWidth > w)
                w = hostMetrics.advanceWidth;
        }
        return Math.min(Math.max(w + 4, 48), 360);
    }

    headerText: "AUSPEX"
    detailsText: {
        const s = service.connectionStatus;
        if (s === "live")
            return cockpit.problemCount + " problème(s) actif(s)";
        if (s === "polling")
            return "interrogation…";
        if (s === "unauthorized")
            return "token refusé — vérifier l'API token (read-only)";
        if (s === "error")
            return service.errorMessage;
        return "non configuré — renseigner URL + token";
    }
    showCloseButton: true

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: cockpit.now = Date.now()
    }

    Item {
        width: parent.width
        height: cockpit.owner.popoutHeight - cockpit.headerHeight - cockpit.detailsHeight - Theme.spacingXL

        // État vide (aucun problème connu).
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: cockpit.problemCount === 0

            DankIcon {
                name: "shield"
                size: 44
                color: "#3f5a44"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: "Aucun signal hostile."
                font.pixelSize: Theme.fontSizeLarge
                color: "#cdd6f4"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Liste des problèmes (ordre du service = sévérité↓ via la query).
        ListView {
            anchors.fill: parent
            visible: cockpit.problemCount > 0
            clip: true
            model: cockpit.service.problems

            delegate: Item {
                id: del

                required property var modelData
                readonly property color sevColor: Format.severityColor(modelData.severity)
                readonly property bool muted: modelData.acknowledged || modelData.suppressed

                width: ListView.view.width
                height: 44

                Rectangle {
                    id: sevBar
                    width: 3
                    height: parent.height
                    color: del.sevColor
                }

                RowLayout {
                    anchors.left: sevBar.right
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Colonne host auto-ajustée au nom le plus long (bornée) → alignée.
                    StyledText {
                        Layout.preferredWidth: cockpit.hostColWidth
                        text: del.modelData.host
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: del.muted ? "#7f849c" : "#cdd6f4"
                    }
                    // Description : remplit le reste → largeur constante (colonnes fixes).
                    StyledText {
                        Layout.fillWidth: true
                        text: del.modelData.trigger
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: del.muted ? "#7f849c" : "#cdd6f4"
                    }
                    // Colonne sévérité à largeur fixe → chips alignés verticalement.
                    Rectangle {
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: 112
                        radius: 6
                        color: "transparent"

                        // Fond tinté (opacité isolée sur ce rectangle, pas sur le texte).
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: del.sevColor
                            opacity: 0.16
                        }

                        StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: Format.severityLabel(del.modelData.severity)
                            font.pixelSize: Theme.fontSizeSmall
                            color: del.sevColor
                        }
                    }
                    // Colonne âge à largeur fixe, alignée à droite.
                    StyledText {
                        Layout.preferredWidth: 56
                        horizontalAlignment: Text.AlignRight
                        text: Format.relativeTime(del.modelData.since, cockpit.now)
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#a6adc8"
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#26283a"
                }
            }
        }
    }
}
