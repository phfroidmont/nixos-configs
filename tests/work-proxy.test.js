const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const firefox = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const brave = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const pacUrl = firefox.policies.Proxy.AutoConfigURL;

assert.deepEqual(firefox.policies.Proxy, {
  Mode: "autoConfig",
  AutoConfigURL: pacUrl,
  Locked: true,
});
assert.deepEqual(brave.ProxySettings, {
  ProxyMode: "pac_script",
  ProxyPacUrl: pacUrl,
  ProxyPacMandatory: true,
});

const prefix = "data:application/x-ns-proxy-autoconfig,";
assert.ok(pacUrl.startsWith(prefix));
const parsedUrl = new URL(pacUrl);
assert.equal(parsedUrl.href, pacUrl);
assert.equal(parsedUrl.hash, "");
const pacScript = decodeURIComponent(pacUrl.slice(prefix.length));
const findProxyForURL = vm.runInNewContext(`${pacScript}\nFindProxyForURL`);

const cases = [
  ["login.microsoftonline.com", "PROXY wsl.foyer.internal:2345"],
  ["LOGIN.MICROSOFTONLINE.COM", "PROXY wsl.foyer.internal:2345"],
  ["microsoftonline.com", "DIRECT"],
  ["other.microsoftonline.com", "DIRECT"],
  ["sub.login.microsoftonline.com", "DIRECT"],
  ["login.microsoftonline.com.example.org", "DIRECT"],
  ["notlogin.microsoftonline.com", "DIRECT"],
  ["login.live.com", "DIRECT"],
  ["wsl.foyer.internal", "DIRECT"],
  ["nexus.foyer.lu", "DIRECT"],
  ["example.org", "DIRECT"],
  ["127.0.0.1", "DIRECT"],
];

for (const [host, expected] of cases) {
  for (const scheme of ["http", "https"]) {
    const url = `${scheme}://${host}/path?next=login.microsoftonline.com`;
    assert.equal(findProxyForURL(url, host), expected, url);
  }
}

console.log(`Passed browser policy validation and ${cases.length * 2} PAC routing cases.`);
