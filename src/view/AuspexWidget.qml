// Widget de barre auspex (plugin DankMaterialShell).
// v0.2.0 : badge d'état (compteur + couleur de la pire sévérité) + popout liste minimale.
// Le cockpit complet (direction C : télémétrie, barre de résumé, filtres, états soignés)
// arrive en v0.3.0 ; les notifications (delta) en v0.4.0.
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../model/format.js" as Format

PluginComponent {
    id: root

    // Réglages lus de pluginData (cf. Settings.qml).
    readonly property string cfgUrl: (pluginData && pluginData.url) ? pluginData.url : ""
    readonly property string cfgToken: (pluginData && pluginData.token) ? pluginData.token : ""
    readonly property bool cfgInsecure: (pluginData && pluginData.insecure) ? pluginData.insecure : false
    readonly property int cfgIntervalMs: (pluginData && pluginData.pollSeconds > 0) ? pluginData.pollSeconds * 1000 : 30000

    readonly property int problemCount: svc.problems.length
    // Couleur de la pire sévérité (vert si RAS) — pilote le badge.
    readonly property string stateColor: Format.severityColor(svc.worstSeverity)

    Zabbix {
        id: svc
        url: root.cfgUrl
        token: root.cfgToken
        insecure: root.cfgInsecure
        intervalMs: root.cfgIntervalMs
    }

    // ---- Pièce de barre : icône radar + badge compteur coloré ----
    horizontalBarPill: Component {
        Item {
            implicitWidth: radarIcon.implicitWidth + Theme.spacingXS
            implicitHeight: radarIcon.implicitHeight

            DankIcon {
                id: radarIcon
                anchors.centerIn: parent
                name: "radar"
                size: Theme.fontSizeLarge
                filled: root.problemCount > 0
                color: root.problemCount > 0 ? root.stateColor : Theme.surfaceTextMedium
            }

            // Badge compteur, ancré en haut-droite de l'icône, couleur = pire sévérité.
            StyledRect {
                id: badge
                visible: root.problemCount > 0
                anchors.horizontalCenter: radarIcon.right
                anchors.verticalCenter: radarIcon.top
                width: Math.max(badgeText.implicitWidth + Theme.spacingXS, height)
                height: badgeText.implicitHeight + 2
                radius: height / 2
                color: root.stateColor

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.problemCount > 99 ? "99+" : String(root.problemCount)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.background
                }
            }
        }
    }

    // ---- Popout : liste minimale des problèmes (le cockpit C = v0.3.0) ----
    popoutContent: Component {
        PopoutComponent {
            id: cockpit

            // Horloge pour rafraîchir « il y a N min ».
            property double now: Date.now()

            headerText: "AUSPEX"
            detailsText: {
                const s = svc.connectionStatus;
                if (s === "live")
                    return root.problemCount + " problème(s) actif(s)";
                if (s === "polling")
                    return "interrogation…";
                if (s === "unauthorized")
                    return "token refusé — vérifier l'API token (read-only)";
                if (s === "error")
                    return svc.errorMessage;
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
                height: root.popoutHeight - cockpit.headerHeight - cockpit.detailsHeight - Theme.spacingXL

                // État vide (aucun problème connu).
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    visible: root.problemCount === 0

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
                    visible: root.problemCount > 0
                    clip: true
                    model: svc.problems

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

                            // Colonne host à largeur fixe (hôtes ~40 car.) → tout s'aligne.
                            StyledText {
                                Layout.preferredWidth: 300
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
    }
    popoutWidth: 820
    popoutHeight: 560
}
