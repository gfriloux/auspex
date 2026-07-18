// Cockpit auspex — contenu du popout (direction C, v0.3.0).
// En-tête télémétrie (état de connexion + refresh), barre de résumé segmentée par sévérité,
// légende cliquable (filtre côté vue), liste enrichie (point de sévérité, icônes ack/
// supprimé), états soignés (vide / chargement / erreur / unauthorized) et pied de cadence.
// Les quick-links de délégation sont reportés à un plan dédié (cf. DESIGN.md).
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

    // Filtre par sévérité, côté vue (n'affecte ni le service ni la barre de résumé) :
    // un booléen par sévérité 0-5, toutes actives par défaut. La légende toggle ces valeurs.
    property var active: [true, true, true, true, true, true]
    function toggleSeverity(s) {
        let a = active.slice();
        a[s] = !a[s];
        active = a;
    }
    // Problèmes après filtre (l'ordre sévérité↓ puis âge du service est préservé).
    readonly property var visibleProblems: {
        return service ? service.problems.filter(p => active[p.severity]) : [];
    }

    // États dérivés de la connexion (best-effort, invariant 7).
    readonly property bool isUnauthorized: service && service.connectionStatus === "unauthorized"
    readonly property bool isError: service && (service.connectionStatus === "error" || isUnauthorized)
    // Chargement = 1er poll sans état connu (on ne masque pas une liste déjà remplie).
    readonly property bool isLoading: service && service.connectionStatus === "polling" && problemCount === 0

    // Horloge pour rafraîchir « il y a N min » (coarse : les âges bougent lentement).
    property double now: Date.now()
    // Tick 1s pour le compte à rebours du pied (n'existe que popout ouvert).
    property double nowTick: Date.now()

    // Cadence de poll pour le pied (−1 si aucun poll encore effectué).
    readonly property int secsSinceLast: (service && service.lastPollAt > 0) ? Math.max(0, Math.floor((nowTick - service.lastPollAt) / 1000)) : -1
    readonly property int secsToNext: (service && service.lastPollAt > 0) ? Math.max(0, Math.round(service.intervalMs / 1000) - secsSinceLast) : -1

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

    // En-tête par défaut de PopoutComponent masqué : on porte notre propre en-tête
    // télémétrie (headerText/detailsText vides → popoutHeader/popoutDetails invisibles).
    headerText: ""

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: cockpit.now = Date.now()
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: cockpit.nowTick = Date.now()
    }

    // ---- En-tête télémétrie (signature direction C) ----
    Rectangle {
        id: header
        width: parent.width
        height: 52
        color: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.6)

        // Gauche : cog radar Mauve, wordmark AUSPEX (mono), « // telemetry » discret.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "radar"
                size: Theme.fontSizeLarge
                color: "#cba6f7"
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "AUSPEX"
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                font.letterSpacing: 2
                color: "#cdd6f4"
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "// telemetry"
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "#6c7086"
            }
        }

        // Droite : point + libellé d'état de connexion, bouton refresh (tourne pendant le
        // poll), bouton close.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            Rectangle {
                id: statusDot
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Format.connectionColor(cockpit.service.connectionStatus)

                // Point « live » qui respire (livedot).
                SequentialAnimation on opacity {
                    running: cockpit.service.connectionStatus === "live"
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.35
                        duration: 1000
                    }
                    NumberAnimation {
                        to: 1
                        duration: 1000
                    }
                }
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Format.connectionLabel(cockpit.service.connectionStatus)
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "#a6adc8"
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28

                DankIcon {
                    id: refreshIcon
                    anchors.centerIn: parent
                    name: "refresh"
                    size: Theme.fontSizeMedium
                    color: refreshArea.containsMouse ? "#cdd6f4" : "#a6adc8"

                    RotationAnimation on rotation {
                        running: cockpit.service.connectionStatus === "polling"
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                    }
                }
                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cockpit.service.poll()
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: Theme.fontSizeMedium
                    color: closeArea.containsMouse ? "#f38ba8" : "#a6adc8"
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cockpit.closePopout)
                            cockpit.closePopout();
                    }
                }
            }
        }
    }

    // Segments de la barre de résumé : sévérités présentes, du plus critique au plus calme
    // (ordre de tri de la liste). `counts` porte les 6 niveaux ("0".."5"), on saute les nuls.
    readonly property var severitySegments: {
        let out = [];
        const c = cockpit.service.counts;
        for (let s = 5; s >= 0; s--) {
            const n = c[String(s)] || 0;
            if (n > 0)
                out.push({
                    "severity": s,
                    "count": n
                });
        }
        return out;
    }

    // ---- Barre de résumé segmentée par sévérité (signature direction C) ----
    Item {
        id: summary
        width: parent.width
        height: 52

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingL

            // Grand compteur total.
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: String(cockpit.problemCount)
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: 20
                font.bold: true
                color: cockpit.problemCount > 0 ? "#cdd6f4" : "#a6e3a1"
            }

            // Barre segmentée : largeur ∝ compte, couleur = sévérité, transition douce.
            Rectangle {
                id: bar
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 12
                radius: 6
                clip: true
                color: "#313244"

                // RAS : barre verte pleine discrète.
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "#a6e3a1"
                    opacity: 0.5
                    visible: cockpit.problemCount === 0
                }

                Row {
                    id: barRow
                    anchors.fill: parent
                    visible: cockpit.problemCount > 0

                    Repeater {
                        model: cockpit.severitySegments

                        delegate: Rectangle {
                            required property var modelData
                            height: barRow.height
                            width: cockpit.problemCount > 0 ? barRow.width * modelData.count / cockpit.problemCount : 0
                            color: Format.severityColor(modelData.severity)

                            Behavior on width {
                                NumberAnimation {
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Légende cliquable = filtre par sévérité (côté vue) ----
    Flow {
        id: legend
        width: parent.width - 2 * Theme.spacingM
        x: Theme.spacingM
        spacing: Theme.spacingXS
        bottomPadding: Theme.spacingXS

        Repeater {
            model: 6 // une entrée par sévérité 0-5 (calme → critique)

            delegate: Rectangle {
                id: entry

                required property int index
                readonly property int cnt: cockpit.service.counts[String(index)] || 0
                readonly property bool on: cockpit.active[index]

                width: entryRow.implicitWidth + 2 * Theme.spacingS
                height: 24
                radius: 6
                color: entryArea.containsMouse ? "#313244" : "transparent"
                // Compte nul → très atténué ; sévérité filtrée (off) → semi-atténuée.
                opacity: entry.cnt === 0 ? 0.4 : (entry.on ? 1 : 0.55)

                Row {
                    id: entryRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 2
                        color: Format.severityColor(entry.index)
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Format.severityLabel(entry.index)
                        font.pixelSize: Theme.fontSizeSmall
                        font.strikeout: !entry.on
                        color: "#a6adc8"
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(entry.cnt)
                        font.family: Theme.defaultMonoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#cdd6f4"
                    }
                }

                MouseArea {
                    id: entryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cockpit.toggleSeverity(entry.index)
                }
            }
        }
    }

    Item {
        id: body
        width: parent.width
        height: cockpit.owner.popoutHeight - header.height - summary.height - legend.height - footer.height - Theme.spacingXL

        // ---- Bandeau erreur / token refusé (dernier état connu conservé dessous) ----
        Rectangle {
            id: banner
            visible: cockpit.isError
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            height: visible ? bannerRow.implicitHeight + 2 * Theme.spacingS : 0
            radius: 8
            color: Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.08)
            border.width: 1
            border.color: Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.3)

            Row {
                id: bannerRow
                anchors.left: parent.left
                anchors.right: retryBtn.left
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: cockpit.isUnauthorized ? "lock" : "error"
                    size: Theme.fontSizeLarge
                    color: "#f38ba8"
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: bannerRow.width - Theme.iconSize - Theme.spacingS
                    text: cockpit.isUnauthorized ? "Vérifier l'API token (utilisateur read-only)." : "Zabbix injoignable — nouvelle tentative bientôt. Affichage du dernier état connu."
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: "#cdd6f4"
                }
            }

            Rectangle {
                id: retryBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                width: retryText.implicitWidth + 2 * Theme.spacingS
                height: 26
                radius: 6
                color: retryArea.containsMouse ? Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.18) : "transparent"
                border.width: 1
                border.color: Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.4)

                StyledText {
                    id: retryText
                    anchors.centerIn: parent
                    text: "Réessayer"
                    font.pixelSize: Theme.fontSizeSmall
                    color: "#f38ba8"
                }
                MouseArea {
                    id: retryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cockpit.service.poll()
                }
            }
        }

        // Zone de contenu sous le bandeau.
        Item {
            id: content
            anchors.top: banner.visible ? banner.bottom : parent.top
            anchors.topMargin: banner.visible ? Theme.spacingS : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            // ---- Chargement : skeleton shimmer (1er poll, rien de connu) ----
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                visible: cockpit.isLoading

                SequentialAnimation on opacity {
                    running: cockpit.isLoading
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.4
                        duration: 700
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 12
                    radius: 6
                    color: "#313244"
                }
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        width: parent.width
                        height: 20
                        radius: 6
                        color: "#26283a"
                    }
                }
            }

            // ---- Vide / zen (aucun problème, connexion saine) ----
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: cockpit.problemCount === 0 && !cockpit.isLoading && !cockpit.isError

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "shield"
                    size: 62
                    color: Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.28)
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Aucun signal hostile."
                    font.pixelSize: Theme.fontSizeLarge
                    color: "#cdd6f4"
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Tous les systèmes nominaux. Balayage actif…"
                    font.pixelSize: Theme.fontSizeSmall
                    color: "#a6adc8"
                }
            }

            // Liste des problèmes (ordre du service = sévérité↓ via la query).
            ListView {
                anchors.fill: parent
                visible: cockpit.problemCount > 0
                clip: true
                model: cockpit.visibleProblems

                delegate: Item {
                    id: del

                    required property var modelData
                    readonly property color sevColor: Format.severityColor(modelData.severity)
                    readonly property bool muted: modelData.acknowledged || modelData.suppressed

                    width: ListView.view.width
                    height: 44

                    HoverHandler {
                        id: rowHover
                    }

                    // Fond de survol.
                    Rectangle {
                        anchors.fill: parent
                        color: "#45475a"
                        opacity: rowHover.hovered ? 0.42 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    // Point de sévérité 9px + halo tinté.
                    Item {
                        id: dotBox
                        width: 26
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        Rectangle {
                            anchors.centerIn: parent
                            width: 17
                            height: 17
                            radius: 8.5
                            color: del.sevColor
                            opacity: 0.16
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 9
                            height: 9
                            radius: 4.5
                            color: del.sevColor
                        }
                    }

                    RowLayout {
                        anchors.left: dotBox.right
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
                        // Icônes d'état : acquitté / supprimé (masquées sinon → pas de gap).
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4
                            visible: del.modelData.acknowledged || del.modelData.suppressed

                            DankIcon {
                                visible: del.modelData.acknowledged
                                name: "task_alt"
                                size: Theme.fontSizeSmall
                                color: "#7f849c"
                            }
                            DankIcon {
                                visible: del.modelData.suppressed
                                name: "notifications_off"
                                size: Theme.fontSizeSmall
                                color: "#7f849c"
                            }
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

                    // Séparateur 1px en dégradé (fondu aux bords) ; s'efface au survol.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        opacity: rowHover.hovered ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }
                            GradientStop {
                                position: 0.5
                                color: "#45475a"
                            }
                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Pied de cadence ----
    Rectangle {
        id: footer
        width: parent.width
        height: 28
        color: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.55)

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: "problem.get · trigger.get"
            font.family: Theme.defaultMonoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: "#6c7086"
        }
        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: cockpit.secsSinceLast < 0 ? "en attente du 1er poll…" : ("last poll " + cockpit.secsSinceLast + " s · next in " + cockpit.secsToNext + " s")
            font.family: Theme.defaultMonoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: "#6c7086"
        }
    }
}
