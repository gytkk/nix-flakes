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
          skin = "one-half-light";
          enableMouse = false;
          headless = false;
          logoless = false;
          crumbsless = false;
          splashless = false;
          reactive = true;
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

    skins.one-half-light = {
      k9s = {
        body = {
          fgColor = "#383a42";
          bgColor = "#fafafa";
          logoColor = "#0184bc";
        };
        prompt = {
          fgColor = "#383a42";
          bgColor = "#fafafa";
          suggestColor = "#0184bc";
        };
        info = {
          fgColor = "#0184bc";
          sectionColor = "#383a42";
        };
        dialog = {
          fgColor = "#383a42";
          bgColor = "#fafafa";
          buttonFgColor = "#ffffff";
          buttonBgColor = "#0184bc";
          buttonFocusFgColor = "#ffffff";
          buttonFocusBgColor = "#d65d0e";
          labelFgColor = "#c18401";
          fieldFgColor = "#383a42";
        };
        frame = {
          border = {
            fgColor = "#e5e5e5";
            focusColor = "#0184bc";
          };
          menu = {
            fgColor = "#383a42";
            keyColor = "#0184bc";
            numKeyColor = "#d65d0e";
          };
          crumbs = {
            fgColor = "#383a42";
            bgColor = "#f0f0f0";
            activeColor = "#bfceff";
          };
          status = {
            newColor = "#0184bc";
            modifyColor = "#c18401";
            addColor = "#50a14f";
            errorColor = "#e45649";
            highlightcolor = "#c18401";
            killColor = "#d65d0e";
            completedColor = "#a0a1a7";
          };
          title = {
            fgColor = "#383a42";
            bgColor = "#f0f0f0";
            highlightColor = "#c18401";
            counterColor = "#0184bc";
            filterColor = "#d65d0e";
          };
        };
        views = {
          charts = {
            bgColor = "default";
            defaultDialColors = [
              "#50a14f"
              "#e45649"
            ];
            defaultChartColors = [
              "#50a14f"
              "#e45649"
            ];
          };
          table = {
            fgColor = "#383a42";
            bgColor = "#fafafa";
            cursorFgColor = "#383a42";
            cursorBgColor = "#bfceff";
            header = {
              fgColor = "#383a42";
              bgColor = "#fafafa";
              sorterColor = "#0184bc";
            };
          };
          xray = {
            fgColor = "#383a42";
            bgColor = "#fafafa";
            cursorColor = "#bfceff";
            graphicColor = "#0184bc";
            showIcons = false;
          };
          yaml = {
            keyColor = "#0184bc";
            colonColor = "#a0a1a7";
            valueColor = "#383a42";
          };
          logs = {
            fgColor = "#383a42";
            bgColor = "#fafafa";
            indicator = {
              fgColor = "#ffffff";
              bgColor = "#0184bc";
              toggleOnColor = "#50a14f";
              toggleOffColor = "#a0a1a7";
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
