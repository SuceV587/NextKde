import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { systemdCommand, unitName } from "./AppLaunchIsolation.mjs";

assert.equal(unitName("org.example.App.desktop", "abc-123"),
    "app-org.example.App-abc-123.service");
assert.equal(unitName("unsafe app/../../.desktop", "nonce/with spaces"),
    "app-unsafe-app-..-..-nonce-with-spaces.service");

const command = systemdCommand(
    ["/usr/bin/example", "--title", "a value; $(not-a-shell)"],
    "org.example.App.desktop", "unique", "/tmp/example dir");
assert.deepEqual(command.slice(0, 7), [
    "systemd-run", "--user", "--quiet", "--collect",
    "--service-type=exec", "--slice=app.slice",
    "--unit=app-org.example.App-unique.service"
]);
assert.ok(command.includes("--working-directory=/tmp/example dir"));
assert.ok(command.includes("--setenv=XDG_ACTIVATION_TOKEN"));
assert.deepEqual(command.slice(-4),
    ["--", "/usr/bin/example", "--title", "a value; $(not-a-shell)"]);
assert.equal(command.includes("sh"), false);
assert.deepEqual(systemdCommand([], "app", "nonce", ""), []);

const service = readFileSync(new URL("AppActionService.qml", import.meta.url), "utf8");
assert.match(service,
    /if \(preserveCommandOnFallback\)[\s\S]*_executeCommandDirect\(command, appId\)/,
    "deep-link fallback preserves its command and arguments");
assert.match(service,
    /else[\s\S]*_executeDirect\(entry, appId, "systemd-run"\)/,
    "ordinary launch failure falls back to DesktopEntry.execute");

console.log("app launch isolation: passed");
