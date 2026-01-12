{
  config,
  lib,
  pkgs,
  homeDirectory,
  ...
}:

{
  programs.k9s = {
    enable = true;

    settings = {
      k9s = {
        liveViewAutoRefresh = false;
        screenDumpDir = "${homeDirectory}/Library/Application Support/k9s/screen-dumps";
        refreshRate = 2;
        maxConnRetry = 5;
        readOnly = false;
        noExitOnCtrlC = false;
        portForwardAddress = "localhost";
        ui = {
          skin = "rose-pine-dawn";
          enableMouse = false;
          headless = false;
          logoless = false;
          crumbsless = false;
          splashless = false;
          reactive = false;
          noIcons = false;
          defaultsToFullScreen = false;
        };
        skipLatestRevCheck = false;
        disablePodCounting = false;
        shellPod = {
          image = "busybox:1.35.0";
          namespace = "default";
          limits = {
            cpu = "100m";
            memory = "100Mi";
          };
        };
        imageScans = {
          enable = false;
          exclusions = {
            namespaces = [ ];
            labels = { };
          };
        };
        logger = {
          tail = 100;
          buffer = 5000;
          sinceSeconds = -1;
          textWrap = false;
          showTime = false;
        };
        thresholds = {
          cpu = {
            critical = 90;
            warn = 70;
          };
          memory = {
            critical = 90;
            warn = 70;
          };
        };
      };
    };

    views = {
      "v1/nodes" = {
        columns = [
          "NAME"
          "STATUS"
          "AGE"
          "INSTANCE-TYPE:.metadata.labels.node\\.kubernetes\\.io/instance-type"
          "NODE-POOL:.metadata.labels.karpenter\\.sh/nodepool"
          "ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone"
        ];
      };
    };

    skins.rose-pine-dawn = {
      k9s = {
        body = {
          fgColor = "#575279";
          bgColor = "#faf4ed";
          logoColor = "#907aa9";
        };
        prompt = {
          fgColor = "#575279";
          bgColor = "#faf4ed";
          suggestColor = "#907aa9";
        };
        info = {
          fgColor = "#907aa9";
          sectionColor = "#575279";
        };
        dialog = {
          fgColor = "#575279";
          bgColor = "#faf4ed";
          buttonFgColor = "#575279";
          buttonBgColor = "#907aa9";
          buttonFocusFgColor = "#ea9d34";
          buttonFocusBgColor = "#907aa9";
          labelFgColor = "#ea9d34";
          fieldFgColor = "#575279";
        };
        frame = {
          border = {
            fgColor = "#f2e9e1";
            focusColor = "#f2e9e1";
          };
          menu = {
            fgColor = "#575279";
            keyColor = "#907aa9";
            numKeyColor = "#907aa9";
          };
          crumbs = {
            fgColor = "#575279";
            bgColor = "#f2e9e1";
            activeColor = "#f2e9e1";
          };
          status = {
            newColor = "#d7827e";
            modifyColor = "#907aa9";
            addColor = "#286983";
            errorColor = "#b4637a";
            highlightcolor = "#ea9d34";
            killColor = "#9893a5";
            completedColor = "#9893a5";
          };
          title = {
            fgColor = "#575279";
            bgColor = "#f2e9e1";
            highlightColor = "#ea9d34";
            counterColor = "#907aa9";
            filterColor = "#907aa9";
          };
        };
        views = {
          charts = {
            bgColor = "default";
            defaultDialColors = [
              "#907aa9"
              "#b4637a"
            ];
            defaultChartColors = [
              "#907aa9"
              "#b4637a"
            ];
          };
          table = {
            fgColor = "#575279";
            bgColor = "#faf4ed";
            header = {
              fgColor = "#575279";
              bgColor = "#faf4ed";
              sorterColor = "#d7827e";
            };
          };
          xray = {
            fgColor = "#575279";
            bgColor = "#faf4ed";
            cursorColor = "#f2e9e1";
            graphicColor = "#907aa9";
            showIcons = false;
          };
          yaml = {
            keyColor = "#907aa9";
            colonColor = "#907aa9";
            valueColor = "#575279";
          };
          logs = {
            fgColor = "#575279";
            bgColor = "#faf4ed";
            indicator = {
              fgColor = "#575279";
              bgColor = "#907aa9";
            };
          };
        };
      };
    };

    skins.catppuccin-latte = {
      k9s = {
        body = {
          fgColor = "#4c4f69";
          bgColor = "#eff1f5";
          logoColor = "#8839ef";
        };
        prompt = {
          fgColor = "#4c4f69";
          bgColor = "#e6e9ef";
          suggestColor = "#1e66f5";
        };
        help = {
          fgColor = "#4c4f69";
          bgColor = "#eff1f5";
          sectionColor = "#40a02b";
          keyColor = "#1e66f5";
          numKeyColor = "#e64553";
        };
        frame = {
          title = {
            fgColor = "#179299";
            bgColor = "#eff1f5";
            highlightColor = "#ea76cb";
            counterColor = "#df8e1d";
            filterColor = "#40a02b";
          };
          border = {
            fgColor = "#8839ef";
            focusColor = "#7287fd";
          };
          menu = {
            fgColor = "#4c4f69";
            keyColor = "#1e66f5";
            numKeyColor = "#e64553";
          };
          crumbs = {
            fgColor = "#eff1f5";
            bgColor = "#e64553";
            activeColor = "#dd7878";
          };
          status = {
            newColor = "#1e66f5";
            modifyColor = "#7287fd";
            addColor = "#40a02b";
            pendingColor = "#fe640b";
            errorColor = "#d20f39";
            highlightColor = "#04a5e5";
            killColor = "#8839ef";
            completedColor = "#9ca0b0";
          };
        };
        info = {
          fgColor = "#fe640b";
          sectionColor = "#4c4f69";
        };
        views = {
          table = {
            fgColor = "#4c4f69";
            bgColor = "#eff1f5";
            cursorFgColor = "#ccd0da";
            cursorBgColor = "#bcc0cc";
            markColor = "#dc8a78";
            header = {
              fgColor = "#df8e1d";
              bgColor = "#eff1f5";
              sorterColor = "#04a5e5";
            };
          };
          xray = {
            fgColor = "#4c4f69";
            bgColor = "#eff1f5";
            cursorColor = "#bcc0cc";
            cursorTextColor = "#eff1f5";
            graphicColor = "#ea76cb";
          };
          charts = {
            bgColor = "#eff1f5";
            chartBgColor = "#eff1f5";
            dialBgColor = "#eff1f5";
            defaultDialColors = [
              "#40a02b"
              "#d20f39"
            ];
            defaultChartColors = [
              "#40a02b"
              "#d20f39"
            ];
            resourceColors = {
              cpu = [
                "#8839ef"
                "#1e66f5"
              ];
              mem = [
                "#df8e1d"
                "#fe640b"
              ];
            };
          };
          yaml = {
            keyColor = "#1e66f5";
            valueColor = "#4c4f69";
            colonColor = "#6c6f85";
          };
          logs = {
            fgColor = "#4c4f69";
            bgColor = "#eff1f5";
            indicator = {
              fgColor = "#7287fd";
              bgColor = "#eff1f5";
              toggleOnColor = "#40a02b";
              toggleOffColor = "#6c6f85";
            };
          };
        };
        dialog = {
          fgColor = "#df8e1d";
          bgColor = "#7c7f93";
          buttonFgColor = "#eff1f5";
          buttonBgColor = "#8c8fa1";
          buttonFocusFgColor = "#eff1f5";
          buttonFocusBgColor = "#ea76cb";
          labelFgColor = "#dc8a78";
          fieldFgColor = "#4c4f69";
        };
      };
    };
  };
}
