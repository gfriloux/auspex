# Module home-manager : installe auspex comme plugin DankMaterialShell.
#
# Assemble le plugin (plugin.json + src/) dans le store et le lie dans le dossier de
# plugins de DMS. L'activation se fait ensuite dans DMS (Settings → Plugins → Auspex),
# puis les réglages (URL de l'API Zabbix, API token read-only, intervalle) dans ce panneau.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.auspex;

  plugin = pkgs.runCommandLocal "auspex-plugin" {} ''
    mkdir -p $out
    cp ${../plugin.json} $out/plugin.json
    cp -r ${../src} $out/src
  '';
in {
  options.programs.auspex.enable =
    lib.mkEnableOption "auspex — widget de supervision Zabbix pour DankMaterialShell";

  config = lib.mkIf cfg.enable {
    # Le plugin est découvert par DMS dans ~/.config/DankMaterialShell/plugins/.
    xdg.configFile."DankMaterialShell/plugins/Auspex".source = plugin;

    # Deps runtime : curl (poll de l'API Zabbix) et notify-send (notifications desktop,
    # fourni par libnotify).
    home.packages = [pkgs.curl pkgs.libnotify];
  };
}
