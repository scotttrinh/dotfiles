# Defaults for coding agents that rewrite their own config files.
#
# home-manager keeps its copy under `agentDefaults.directory` and never links
# it into the tool's config path. Activation merges it into the tool's real,
# writable file instead (see ./merge.py), so the managed values act as a layer
# below the tool's own settings: edits the tool makes win, untouched values
# follow home-manager, and deleted keys fall back to the default.
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.agentDefaults;

  defaultsPath = name: "${cfg.directory}/${name}";
  templateName = name: "agent-defaults-${lib.replaceStrings [ "/" ] [ "-" ] name}";

  secretFiles = lib.filterAttrs (_: file: file.secret) cfg.files;
  plainFiles = lib.filterAttrs (_: file: !file.secret) cfg.files;

  sopsActive = config.sops.secrets != { };
  # sops-nix renders synchronously on Linux. On darwin it renders from a launchd
  # agent that setupLaunchAgents reloads when the templates change, so merge
  # after that and wait for the loaded job to finish its run.
  waitForSops = sopsActive && secretFiles != { } && pkgs.stdenv.isDarwin;
  sopsJob = "gui/$(id -u)/${lib.escapeShellArg config.launchd.agents.sops-nix.config.Label}";

  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  merge = pkgs.writeScript "agent-defaults-merge" ''
    #!${python.interpreter}
    ${builtins.readFile ./merge.py}
  '';

  mergeCommand = name: file: ''
    run ${merge} ${file.format} \
      ${lib.escapeShellArg (defaultsPath name)} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/${file.target}"} \
      ${lib.escapeShellArg "${cfg.stateDirectory}/${name}"}
  '';
in
{
  options.agentDefaults = {
    directory = mkOption {
      type = types.str;
      default = "${config.xdg.configHome}/agent-defaults";
      description = "Where home-manager places managed agent defaults.";
    };

    stateDirectory = mkOption {
      type = types.str;
      default = "${config.xdg.stateHome}/agent-defaults";
      description = "Where the last applied defaults are kept for three-way merging.";
    };

    files = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            target = mkOption {
              type = types.str;
              example = ".claude/settings.json";
              description = "Tool-owned config file, relative to the home directory.";
            };

            format = mkOption {
              type = types.enum [ "json" "yaml" ];
              default = "json";
              description = "Format of the target file.";
            };

            content = mkOption {
              type = types.str;
              description = "Default config content. JSON is accepted for yaml targets.";
            };

            secret = lib.mkEnableOption "rendering content through sops-nix so `config.sops.placeholder` values are substituted";
          };
        }
      );
      default = { };
      description = ''
        Managed defaults keyed by their path under `agentDefaults.directory`,
        merged into each tool-owned target on activation.
      '';
    };
  };

  config = lib.mkIf (cfg.files != { }) {
    xdg.configFile = lib.mapAttrs'
      (
        name: file: lib.nameValuePair "agent-defaults/${name}" { text = file.content; }
      )
      plainFiles;

    sops.templates = lib.mapAttrs'
      (
        name: file:
          lib.nameValuePair (templateName name) {
            inherit (file) content;
            path = defaultsPath name;
          }
      )
      secretFiles;

    home.activation.agentDefaults = lib.hm.dag.entryAfter
      (
        [ "linkGeneration" ]
        ++ lib.optional sopsActive "sops-nix"
        ++ lib.optional waitForSops "setupLaunchAgents"
      )
      ''
        ${lib.optionalString waitForSops ''
          agentDefaultsSopsRendered() {
            local info runs=$'\n\truns = [1-9]'
            info="$(/bin/launchctl print ${sopsJob} 2>/dev/null)" || return 1
            [[ $info == *$'\n\tstate = not running'* && $info =~ $runs ]]
          }
          if [[ ! -v DRY_RUN ]]; then
            for _ in $(seq 1 100); do
              if agentDefaultsSopsRendered; then break; fi
              sleep 0.1
            done
            if ! agentDefaultsSopsRendered; then
              warnEcho "sops-nix has not finished rendering; merging the previous agent defaults"
            fi
          fi
        ''}
        ${lib.concatStrings (lib.mapAttrsToList mergeCommand cfg.files)}
      '';
  };
}
