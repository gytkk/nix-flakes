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
            defaultDialColors = [ "#907aa9" "#b4637a" ];
            defaultChartColors = [ "#907aa9" "#b4637a" ];
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
  };
}
