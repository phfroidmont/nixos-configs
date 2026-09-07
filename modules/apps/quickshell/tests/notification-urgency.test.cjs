const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), logic);

for (const identity of [
  { appName: 'Brave' },
  { appName: 'Brave Browser' },
  { appName: 'brave-browser' },
  { appName: 'Microsoft Teams', desktopEntry: 'brave-browser' },
  { appName: 'Microsoft Teams', desktopEntry: 'brave-browser.desktop' },
]) {
  for (const urgency of [0, 1, 2]) {
    const notification = { ...identity, urgency };
    assert.equal(logic.snapshotOf(notification).urgency, 1, JSON.stringify(notification));
    assert.equal(logic.replacementSnapshot(notification, 42, 100).urgency, 1);
  }
}

for (const appName of ['Firefox', 'Chromium', 'notify-send', 'Bravery', '']) {
  for (const urgency of [0, 1, 2]) {
    assert.equal(logic.snapshotOf({ appName, urgency }).urgency, urgency);
    assert.equal(logic.replacementSnapshot({ appName, urgency }, 42, 100).urgency, urgency);
  }
}
console.log('Notification urgency tests passed');
