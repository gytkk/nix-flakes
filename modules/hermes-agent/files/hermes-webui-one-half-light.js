(() => {
  const themeName = "one-half-light";
  const themeLabel = "One Half Light";
  const builtInThemes = [
    "dark",
    "light",
    "slate",
    "solarized",
    "monokai",
    "nord",
    "oled",
  ];

  function ensureThemeOption() {
    const select = document.getElementById("settingsTheme");
    if (!select) {
      return false;
    }

    const exists = Array.from(select.options).some(
      (option) => option.value === themeName,
    );
    if (!exists) {
      const option = document.createElement("option");
      option.value = themeName;
      option.textContent = themeLabel;
      select.appendChild(option);
    }

    const currentTheme =
      document.documentElement.dataset.theme ||
      localStorage.getItem("hermes-theme");
    if (currentTheme === themeName) {
      select.value = themeName;
    }

    return true;
  }

  function patchThemeCommand() {
    if (typeof COMMANDS === "undefined" || !Array.isArray(COMMANDS)) {
      return false;
    }

    const command = COMMANDS.find((item) => item.name === "theme");
    if (!command || command.__oneHalfLightPatched) {
      return Boolean(command);
    }

    const supportedThemes = [...builtInThemes, themeName];
    const original = command.fn;

    command.fn = async function patchedThemeCommand(args) {
      const normalized = (args || "").trim().toLowerCase();
      if (!normalized || !supportedThemes.includes(normalized)) {
        if (typeof showToast === "function" && typeof t === "function") {
          showToast(t("theme_usage") + supportedThemes.join("|"));
        }
        return;
      }

      if (normalized !== themeName) {
        return original.call(this, args);
      }

      document.documentElement.dataset.theme = themeName;
      localStorage.setItem("hermes-theme", themeName);

      try {
        await api("/api/settings", {
          method: "POST",
          body: JSON.stringify({ theme: themeName }),
        });
      } catch (error) {
      }

      ensureThemeOption();
      const select = document.getElementById("settingsTheme");
      if (select) {
        select.value = themeName;
      }

      if (typeof showToast === "function" && typeof t === "function") {
        showToast(t("theme_set") + themeName);
      }
    };

    if (typeof command.desc === "string" && !command.desc.includes(themeName)) {
      command.desc = `${command.desc}, ${themeName}`;
    }

    command.__oneHalfLightPatched = true;
    return true;
  }

  function init() {
    ensureThemeOption();
    patchThemeCommand();
    ensureThemeOption();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }

  window.addEventListener("pageshow", init);
})();
