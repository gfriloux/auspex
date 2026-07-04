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
        Rectangle {
            id: popout
            color: "#1e1e2e"
            radius: 12

            readonly property bool errored: svc.connectionStatus === "error" || svc.connectionStatus === "unauthorized"

            Column {
                anchors.fill: parent
                spacing: 0

                // En-tête : wordmark + état de connexion.
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#181825"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        StyledText {
                            text: "AUSPEX"
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: "#cdd6f4"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: svc.connectionStatus === "live" ? "#a6e3a1" : (svc.connectionStatus === "polling" ? "#cba6f7" : "#f38ba8")
                        }
                        StyledText {
                            text: svc.connectionStatus
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#a6adc8"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Bandeau d'erreur (best-effort : la liste reste visible en dessous).
                Rectangle {
                    width: parent.width
                    height: 34
                    visible: popout.errored
                    color: "#2a1e28"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        elide: Text.ElideRight
                        text: svc.errorMessage
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#f38ba8"
                    }
                }

                // État vide (aucun problème).
                Item {
                    width: parent.width
                    height: 140
                    visible: root.problemCount === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

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
                }

                // Liste des problèmes (ordre du service = sévérité↓ via la query).
                ListView {
                    width: parent.width
                    height: root.popoutHeight - 40 - (popout.errored ? 34 : 0)
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

                            StyledText {
                                Layout.preferredWidth: 66
                                text: del.modelData.host
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: del.muted ? "#7f849c" : "#cdd6f4"
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: del.modelData.trigger
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeSmall
                                color: del.muted ? "#7f849c" : "#cdd6f4"
                            }
                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: chipText.implicitWidth + 16
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
                            StyledText {
                                text: Format.relativeTime(del.modelData.since, Date.now())
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
    popoutWidth: 440
    popoutHeight: 520
}
