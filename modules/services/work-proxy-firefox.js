(() => {
  async function loadExtension() {
    if (Services.appinfo.inSafeMode) {
      return;
    }

    const { AddonManager } = ChromeUtils.importESModule(
      "resource://gre/modules/AddonManager.sys.mjs",
    );
    await AddonManager.readyPromise;
    if (Services.startup.shuttingDown) {
      return;
    }

    const existing = await AddonManager.getAddonByID("foyer-impersonation@foyer.lu");
    if (existing) {
      Services.console.logStringMessage(
        "[work-proxy-firefox] Keeping the existing Foyer Impersonation extension.",
      );
      return;
    }
    if (Services.startup.shuttingDown) {
      return;
    }

    const archive = Components.classes["@mozilla.org/file/local;1"].createInstance(
      Components.interfaces.nsIFile,
    );
    archive.initWithPath("@extensionPath@");
    const addon = await AddonManager.installTemporaryAddon(archive);
    Services.console.logStringMessage(
      `[work-proxy-firefox] Loaded ${addon.id} ${addon.version} as a temporary extension.`,
    );
  }

  const observer = {
    observe() {
      Services.obs.removeObserver(this, "final-ui-startup");
      loadExtension().catch((error) => {
        Services.console.logStringMessage(
          `[work-proxy-firefox] Failed to load Foyer Impersonation: ${error}`,
        );
      });
    },
  };
  Services.obs.addObserver(observer, "final-ui-startup");
})();
