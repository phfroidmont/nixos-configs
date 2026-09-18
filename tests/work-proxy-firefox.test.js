#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const extensionId = "foyer-impersonation@foyer.lu";
const startupTopic = "final-ui-startup";
const settle = () => new Promise((resolve) => setImmediate(resolve));

function readWrapper(root) {
  const firefox = path.join(root, "lib/firefox");
  const config = fs.readFileSync(path.join(firefox, "mozilla.cfg"), "utf8");
  assert.match(
    config.split("\n", 1)[0],
    /^\s*\/\//,
    "mozilla.cfg starts with a comment",
  );
  return {
    config,
    prefs: fs.readFileSync(path.join(firefox, "defaults/pref/autoconfig.js"), "utf8"),
  };
}

function mockFirefox(wrapper, options = {}) {
  const calls = {
    added: 0, removed: 0, imports: [], lookups: [], installs: [], logs: [],
  };
  const prefs = [];
  const observers = new Set();
  let ready;
  const readyPromise = new Promise((resolve) => {
    ready = resolve;
  });
  const services = {
    appinfo: { inSafeMode: Boolean(options.safeMode) },
    startup: { shuttingDown: Boolean(options.shuttingDown) },
    console: { logStringMessage: (message) => calls.logs.push(message) },
    obs: {
      addObserver(observer, topic) {
        assert.equal(topic, startupTopic);
        calls.added++;
        observers.add(observer);
      },
      removeObserver(observer, topic) {
        assert.equal(topic, startupTopic);
        assert.ok(observers.delete(observer), "remove the registered observer only once");
        calls.removed++;
      },
    },
  };
  const nsIFile = Symbol("nsIFile");
  const archive = {
    initWithPath(filename) {
      assert.match(filename, /^\/nix\/store\/[a-z0-9]{32}-[^/]+\.xpi$/);
      const stat = fs.statSync(filename);
      assert.ok(stat.isFile(), "extension archive exists in the store");
      assert.equal(stat.mode & 0o222, 0, "extension archive is read-only");
      this.path = filename;
    },
  };
  const recordPref = (name, value) => prefs.push([name, value]);
  const context = vm.createContext({
    pref: recordPref,
    defaultPref: recordPref,
    lockPref: recordPref,
    Services: services,
    Components: {
      interfaces: { nsIFile },
      classes: {
        "@mozilla.org/file/local;1": {
          createInstance(type) {
            assert.equal(type, nsIFile);
            return archive;
          },
        },
      },
    },
    ChromeUtils: {
      importESModule(uri) {
        calls.imports.push(uri);
        assert.equal(uri, "resource://gre/modules/AddonManager.sys.mjs");
        if (options.initializationError) throw new Error("initialization failed");
        return {
          AddonManager: {
            readyPromise,
            async getAddonByID(id) {
              calls.lookups.push(id);
              assert.equal(id, extensionId);
              if (options.shutdownDuringLookup) services.startup.shuttingDown = true;
              return options.existing ? { id } : null;
            },
            async installTemporaryAddon(file) {
              assert.equal(file, archive);
              assert.ok(file.path, "initialize the local file before installing");
              calls.installs.push(file.path);
              if (options.installError) throw new Error("install failed");
              return { id: extensionId, version: "2.0.2" };
            },
          },
        };
      },
    },
  });
  vm.runInContext(wrapper.prefs, context, { filename: "autoconfig.js" });
  const autoconfigPrefs = new Map(prefs);
  vm.runInContext(wrapper.config, context, { filename: "mozilla.cfg" });
  return {
    calls,
    prefs,
    autoconfigPrefs,
    ready,
    startup() {
      for (const observer of [...observers]) observer.observe(null, startupTopic, null);
    },
  };
}

function checkPrefs(firefox, enabled) {
  assert.equal(firefox.autoconfigPrefs.get("general.config.filename"), "mozilla.cfg");
  assert.equal(firefox.autoconfigPrefs.get("general.config.obscure_value"), 0);
  if (enabled) {
    assert.equal(firefox.autoconfigPrefs.get("general.config.sandbox_enabled"), false);
  }
  for (const [name, value] of firefox.prefs) {
    if (
      name === "xpinstall.signatures.required" ||
      name === "extensions.langpacks.signatures.required"
    ) {
      assert.notEqual(value, false, `must not disable ${name}`);
    }
    if (!enabled && name === "general.config.sandbox_enabled") {
      assert.notEqual(value, false, "disabled wrapper must not disable the sandbox");
    }
  }
}

function checkEidLinks(enabledRoot, disabledRoot) {
  const enabled = path.join(enabledRoot, "lib/mozilla/pkcs11-modules");
  const disabled = path.join(disabledRoot, "lib/mozilla/pkcs11-modules");
  const entries = fs.readdirSync(enabled).sort();
  assert.ok(entries.length > 0, "eID module directory must not be empty");
  assert.deepEqual(entries, fs.readdirSync(disabled).sort());
  for (const entry of entries) {
    const enabledLink = path.join(enabled, entry);
    const disabledLink = path.join(disabled, entry);
    assert.ok(fs.lstatSync(enabledLink).isSymbolicLink(), `enabled eID link: ${entry}`);
    assert.ok(fs.lstatSync(disabledLink).isSymbolicLink(), `disabled eID link: ${entry}`);
    assert.equal(fs.realpathSync(enabledLink), fs.realpathSync(disabledLink));
  }
}

async function startReady(firefox) {
  firefox.ready();
  firefox.startup();
  await settle();
  firefox.startup();
  await settle();
  assert.equal(firefox.calls.added, 1);
  assert.equal(firefox.calls.removed, 1);
}

async function main() {
  const [enabledRoot, disabledRoot] = process.argv.slice(2);
  assert.ok(
    enabledRoot && disabledRoot,
    "usage: work-proxy-firefox.test.js ENABLED_FIREFOX DISABLED_FIREFOX",
  );
  const enabled = readWrapper(enabledRoot);
  const disabled = readWrapper(disabledRoot);
  checkEidLinks(enabledRoot, disabledRoot);

  const unhandled = [];
  const onUnhandled = (error) => unhandled.push(error);
  process.on("unhandledRejection", onUnhandled);
  try {
    const firefox = mockFirefox(enabled);
    checkPrefs(firefox, true);
    await settle();
    assert.equal(firefox.calls.added, 1);
    assert.deepEqual(firefox.calls.imports, [], "wait for final-ui-startup");
    assert.deepEqual(firefox.calls.installs, []);
    firefox.startup();
    await settle();
    assert.equal(firefox.calls.removed, 1);
    assert.equal(firefox.calls.imports.length, 1);
    assert.deepEqual(firefox.calls.lookups, [], "wait for AddonManager.readyPromise");
    assert.deepEqual(firefox.calls.installs, []);
    firefox.ready();
    await settle();
    firefox.startup();
    await settle();
    assert.equal(firefox.calls.removed, 1);
    assert.deepEqual(firefox.calls.lookups, [extensionId]);
    assert.equal(firefox.calls.installs.length, 1);
    assert.deepEqual(firefox.calls.logs, [
      `[work-proxy-firefox] Loaded ${extensionId} 2.0.2 as a temporary extension.`,
    ]);

    const off = mockFirefox(disabled);
    checkPrefs(off, false);
    off.ready();
    off.startup();
    await settle();
    assert.equal(off.calls.added, 0, "disabled wrapper must not register the loader");
    assert.equal(off.calls.removed, 0);
    assert.deepEqual(off.calls.imports, []);
    assert.deepEqual(off.calls.installs, []);
    assert.deepEqual(off.calls.logs, []);

    const safeMode = mockFirefox(enabled, { safeMode: true });
    await startReady(safeMode);
    assert.deepEqual(safeMode.calls.imports, []);
    assert.deepEqual(safeMode.calls.installs, []);
    assert.deepEqual(safeMode.calls.logs, []);

    const shutdown = mockFirefox(enabled, { shuttingDown: true });
    await startReady(shutdown);
    assert.deepEqual(shutdown.calls.lookups, []);
    assert.deepEqual(shutdown.calls.installs, []);
    assert.deepEqual(shutdown.calls.logs, []);

    const lateShutdown = mockFirefox(enabled, { shutdownDuringLookup: true });
    await startReady(lateShutdown);
    assert.deepEqual(lateShutdown.calls.lookups, [extensionId]);
    assert.deepEqual(lateShutdown.calls.installs, []);
    assert.deepEqual(lateShutdown.calls.logs, []);

    const existing = mockFirefox(enabled, { existing: true });
    await startReady(existing);
    assert.deepEqual(existing.calls.lookups, [extensionId]);
    assert.deepEqual(existing.calls.installs, []);
    assert.deepEqual(existing.calls.logs, [
      "[work-proxy-firefox] Keeping the existing Foyer Impersonation extension.",
    ]);

    for (const [option, message] of [
      ["initializationError", "initialization failed"],
      ["installError", "install failed"],
    ]) {
      const failed = mockFirefox(enabled, { [option]: true });
      await startReady(failed);
      assert.equal(failed.calls.installs.length, option === "installError" ? 1 : 0);
      assert.deepEqual(failed.calls.logs, [
        `[work-proxy-firefox] Failed to load Foyer Impersonation: Error: ${message}`,
      ]);
    }
    await settle();
    assert.deepEqual(unhandled, [], "loader errors must not become unhandled rejections");
  } finally {
    process.removeListener("unhandledRejection", onUnhandled);
  }
  console.log("Passed generated Firefox wrapper, eID, and extension loader checks.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
