const forwardedEnvironment = [
    "DISPLAY",
    "WAYLAND_DISPLAY",
    "XAUTHORITY",
    "DBUS_SESSION_BUS_ADDRESS",
    "XDG_CURRENT_DESKTOP",
    "XDG_SESSION_TYPE",
    "XDG_ACTIVATION_TOKEN",
    "DESKTOP_STARTUP_ID"
];

export function unitName(appId, nonce) {
    const safeId = String(appId || "app")
        .replace(/\.desktop$/i, "")
        .replace(/[^A-Za-z0-9_.:-]/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 120) || "app";
    const safeNonce = String(nonce || "launch")
        .replace(/[^A-Za-z0-9_.:-]/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 48) || "launch";
    return "app-" + safeId + "-" + safeNonce + ".service";
}

export function systemdCommand(command, appId, nonce, workingDirectory) {
    if (!Array.isArray(command) || command.length === 0)
        return [];

    const result = [
        "systemd-run",
        "--user",
        "--quiet",
        "--collect",
        "--service-type=exec",
        "--slice=app.slice",
        "--unit=" + unitName(appId, nonce)
    ];
    const directory = String(workingDirectory || "").trim();
    if (directory)
        result.push("--working-directory=" + directory);
    for (let i = 0; i < forwardedEnvironment.length; i++)
        result.push("--setenv=" + forwardedEnvironment[i]);
    result.push("--");
    for (let i = 0; i < command.length; i++)
        result.push(String(command[i]));
    return result;
}
