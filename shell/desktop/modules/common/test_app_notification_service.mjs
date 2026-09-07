import assert from "node:assert";

function normalize(value) {
    return String(value ?? "").replace(/<\d+>$/, "")
        .replace(/\.desktop$/i, "").toLowerCase()
        .replace(/[-_\s.]/g, "");
}

function countForApp(groups, appId, appName) {
    if (!groups || groups.length === 0) return 0;
    const rawAppId = String(appId ?? "").trim();
    const rawAppName = String(appName ?? "").trim();
    const normAppId = normalize(rawAppId);
    const normAppName = normalize(rawAppName);

    let total = 0;
    for (let i = 0; i < groups.length; i++) {
        const g = groups[i];
        if (!g || !g.count) continue;
        const gKey = String(g.groupKey ?? "").trim();
        const gApp = String(g.appName ?? "").trim();
        const normGKey = normalize(gKey);
        const normGApp = normalize(gApp);

        let match = false;
        if (gKey && (gKey === rawAppId || gKey + ".desktop" === rawAppId || rawAppId + ".desktop" === gKey)) {
            match = true;
        } else if (normGKey && (normGKey === normAppId || normGKey === normAppName)) {
            match = true;
        } else if (normGApp && (normGApp === normAppId || normGApp === normAppName)) {
            match = true;
        } else if (normAppId && normGKey && (normAppId.endsWith(normGKey) || normGKey.endsWith(normAppId))) {
            match = true;
        }

        if (match) {
            total += g.count;
        }
    }
    return total;
}

// Tests
const testGroups = [
    { groupKey: "org.kde.dolphin.desktop", appName: "Dolphin", count: 3 },
    { groupKey: "com.tencent.wechat", appName: "微信", count: 5 },
    { groupKey: "code", appName: "Visual Studio Code", count: 1 },
    { groupKey: "telegram-desktop", appName: "Telegram", count: 2 },
];

assert.strictEqual(countForApp(testGroups, "org.kde.dolphin.desktop", "Dolphin"), 3);
assert.strictEqual(countForApp(testGroups, "org.kde.dolphin", "Dolphin"), 3);
assert.strictEqual(countForApp(testGroups, "dolphin.desktop", "文件管理器"), 3);
assert.strictEqual(countForApp(testGroups, "com.tencent.wechat.desktop", "微信"), 5);
assert.strictEqual(countForApp(testGroups, "wechat.desktop", "微信"), 5);
assert.strictEqual(countForApp(testGroups, "code.desktop", "Code"), 1);
assert.strictEqual(countForApp(testGroups, "org.telegram.desktop.desktop", "Telegram"), 2);
assert.strictEqual(countForApp(testGroups, "nonexistent.desktop", "Unknown"), 0);

console.log("All AppNotificationService matching tests passed!");
