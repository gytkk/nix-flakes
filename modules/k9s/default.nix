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
          skin = "material-light";
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
  };
}
