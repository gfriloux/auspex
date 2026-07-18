// Widget de barre auspex (plugin DankMaterialShell).
// Pièce de barre : badge d'état (compteur + couleur de la pire sévérité). Le popout est le
// cockpit direction C, dans Cockpit.qml. Les notifications (delta) arrivent en v0.4.0.
import QtQuick
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
    // Notifications : activation (défaut on) + seuil de sévérité mini (0 = toutes).
    readonly property bool cfgNotifyEnabled: (pluginData && pluginData.notifyEnabled !== undefined) ? pluginData.notifyEnabled : true
    readonly property int cfgNotifyMinSeverity: (pluginData && pluginData.notifyMinSeverity !== undefined) ? parseInt(pluginData.notifyMinSeverity) : 0

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

    // ---- Popout : cockpit direction C (Cockpit.qml) ----
    popoutContent: Component {
        Cockpit {
            service: svc
            owner: root
        }
    }
    popoutWidth: 820
    popoutHeight: 560
}
