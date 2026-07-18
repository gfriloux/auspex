// Réglages du plugin (PluginSettings de DMS). Déclaratif : chaque *Setting auto-persiste
// dans pluginData via son settingKey. Le widget (AuspexWidget) lit url / token / insecure /
// pollSeconds et les injecte dans le service Zabbix.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "auspex"

    StyledText {
        width: parent.width
        text: "Réglages Auspex"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "url"
        label: "URL de l'API Zabbix"
        description: "Endpoint JSON-RPC de l'instance Zabbix 7.0. Ex. « https://zabbix.example.com/api_jsonrpc.php »."
        placeholder: "https://zabbix.example.com/api_jsonrpc.php"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "token"
        label: "API token (utilisateur read-only)"
        description: "Token d'un utilisateur Zabbix en lecture seule (Users → API tokens). Stocké en clair dans la config du plugin ; envoyé en header Authorization: Bearer."
        placeholder: "0424bd59b807674191e7d77572075f33"
        defaultValue: ""
    }

    SliderSetting {
        settingKey: "pollSeconds"
        label: "Intervalle de poll"
        description: "Fréquence d'interrogation de l'API (secondes). Lecture seule, aucune écriture."
        defaultValue: 30
        minimum: 5
        maximum: 300
        unit: "s"
        leftIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "insecure"
        label: "Certificat TLS non vérifié"
        description: "À activer uniquement si l'instance Zabbix présente un certificat auto-signé (curl -k)."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "notifyEnabled"
        label: "Notifications"
        description: "Afficher une notification desktop à l'apparition d'un nouveau problème (via notify-send)."
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "notifyMinSeverity"
        label: "Seuil de sévérité"
        description: "Ne notifier (et ne pulser le badge) qu'à partir de cette sévérité."
        defaultValue: "0"
        options: [
            {
                "value": "0",
                "label": "Toutes"
            },
            {
                "value": "1",
                "label": "Information et +"
            },
            {
                "value": "2",
                "label": "Warning et +"
            },
            {
                "value": "3",
                "label": "Average et +"
            },
            {
                "value": "4",
                "label": "High et +"
            },
            {
                "value": "5",
                "label": "Disaster seulement"
            }
        ]
    }
}
