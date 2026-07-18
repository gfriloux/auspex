// Widget de barre auspex (plugin DankMaterialShell).
// Pièce de barre : badge d'état (compteur + couleur de la pire sévérité). Le popout est le
// cockpit direction C, dans Cockpit.qml. Les notifications (delta) arrivent en v0.4.0.
import QtQuick
import Quickshell
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

    // Pulse « nouveau problème » du badge : indépendant du toggle notifications (indice
    // in-barre discret), mais respecte le seuil de sévérité comme la notif.
    property bool notifyPulse: false
    property color pulseColor: "#f38ba8"

    Zabbix {
        id: svc
        url: root.cfgUrl
        token: root.cfgToken
        insecure: root.cfgInsecure
        intervalMs: root.cfgIntervalMs
    }

    // Nouveaux problèmes → effets de bord (le service n'émet qu'un signal de données).
    Connections {
        target: svc
        function onProblemsAppeared(added) {
            // Filtre par seuil de sévérité (pilote notif ET pulse).
            const qualifying = added.filter(p => p.severity >= root.cfgNotifyMinSeverity);
            if (qualifying.length === 0)
                return;
            root._pulse(qualifying);
            root._notify(qualifying);
        }
    }

    // Déclenche le pulse du badge, coloré par la pire sévérité du lot (~3 cycles de 1.8s).
    function _pulse(qualifying) {
        let worst = -1;
        for (let i = 0; i < qualifying.length; i++)
            worst = Math.max(worst, qualifying[i].severity);
        root.pulseColor = Format.severityColor(worst);
        root.notifyPulse = true;
        pulseStopTimer.restart();
    }
    Timer {
        id: pulseStopTimer
        interval: 5400
        onTriggered: root.notifyPulse = false
    }

    // Notification desktop via notify-send (→ daemon DMS). Gated par le toggle.
    function _notify(qualifying) {
        if (!root.cfgNotifyEnabled)
            return;
        const c = Format.notificationContent(qualifying, Date.now());
        const urgency = Format.notificationUrgency(qualifying);
        const icon = urgency === "critical" ? "dialog-error" : "dialog-warning";
        Quickshell.execDetached(["notify-send", "-a", "Auspex", "-u", urgency, "-i", icon, c.title, c.body]);
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

            // Anneau de pulse à l'apparition d'un nouveau problème (couleur = pire sévérité).
            Rectangle {
                id: pulseRing
                visible: root.notifyPulse
                anchors.centerIn: radarIcon
                width: radarIcon.implicitWidth
                height: radarIcon.implicitHeight
                radius: Math.max(width, height) / 2
                color: "transparent"
                border.width: 2
                border.color: root.pulseColor

                SequentialAnimation {
                    running: root.notifyPulse
                    loops: Animation.Infinite

                    ParallelAnimation {
                        NumberAnimation {
                            target: pulseRing
                            property: "scale"
                            from: 0.8
                            to: 1.9
                            duration: 1800
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: pulseRing
                            property: "opacity"
                            from: 0.7
                            to: 0
                            duration: 1800
                            easing.type: Easing.OutCubic
                        }
                    }
                }
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
