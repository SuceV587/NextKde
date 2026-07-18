pragma Singleton
import QtQuick
import Quickshell

// AppIdentityService — the single identity boundary for applications.
//
// Persistent configuration stores canonical desktop IDs (for example
// "code.desktop"). Runtime window providers may expose a different raw value
// (for example "Code" or "code"). Every consumer must resolve through this
// service instead of comparing provider-specific strings directly.

QtObject {
    id: svc

    property var _cache: ({})
    // Consumers use this explicit revision to rebuild after asynchronous
    // DesktopEntries or icon override changes. Cache mutation alone is easy
    // to miss when the cache is already empty.
    property int revision: 0

    function _key(value) {
        return String(value ?? "").trim().toLowerCase();
    }

    // Normalized comparison key. This is not persisted; desktopId is.
    function normalize(value) {
        return String(value ?? "")
            .replace(/<\d+>$/, "")
            .replace(/\.desktop$/i, "")
            .toLowerCase()
            .replace(/[-_\s.]/g, "");
    }

    function _isDirectIconSource(value) {
        const source = String(value ?? "").trim();
        return source.startsWith("/")
            || source.startsWith(":/")
            || /^[a-z][a-z0-9+.-]*:/i.test(source);
    }

    function _iconPath(candidate) {
        const value = String(candidate ?? "").trim();
        if (!value)
            return "";
        if (_isDirectIconSource(value))
            return value;

        try {
            if (!Quickshell.hasThemeIcon(value))
                return "";
            return Quickshell.iconPath(value, true) || "";
        } catch (e) {
            return "";
        }
    }

    function _candidates(rawId) {
        const values = [];
        const raw = String(rawId ?? "").trim();
        const withoutInstance = raw.replace(/<\d+>$/, "");

        function append(value) {
            const candidate = String(value ?? "").trim();
            if (candidate && values.indexOf(candidate) < 0)
                values.push(candidate);
        }

        append(raw);
        append(withoutInstance);
        const snapshot = values.slice();
        for (let i = 0; i < snapshot.length; i++) {
            const candidate = snapshot[i];
            if (/\.desktop$/i.test(candidate))
                append(candidate.replace(/\.desktop$/i, ""));
            else
                append(candidate + ".desktop");
        }
        return values;
    }

    function _normalizedLookup(value) {
        return String(value ?? "")
            .replace(/<\d+>$/, "")
            .replace(/\.desktop$/i, "")
            .toLowerCase()
            .replace(/[-_\s.]/g, "");
    }

    function _entryHasIcon(entry) {
        return !!_iconPath(entry?.icon ?? "");
    }

    // Window app IDs do not always equal the desktop filename. For example,
    // CC Switch may expose "cc-switch" while its desktop entry is
    // "com.ccswitch.desktop.desktop" and its startup class is "cc-switch".
    // Keep startupClass/id matching as a final fallback, but prefer entries
    // that actually provide a usable icon.
    function _scoreEntry(entry, lookup, normalizedLookup) {
        if (!entry || !_entryHasIcon(entry))
            return -1;

        const startup = String(entry.startupClass ?? "").toLowerCase();
        const id = String(entry.id ?? "").toLowerCase();
        const normalizedId = _normalizedLookup(entry.id);
        const normalizedStartup = _normalizedLookup(entry.startupClass);
        let score = -1;

        if (startup && startup === lookup)
            score = 500;
        else if (id && id === lookup)
            score = 400;
        else if (normalizedStartup && normalizedStartup === normalizedLookup)
            score = 350;
        else if (normalizedId && normalizedId === normalizedLookup)
            score = 300;
        else if (normalizedId && normalizedLookup
                 && (normalizedId.indexOf(normalizedLookup) >= 0
                     || normalizedLookup.indexOf(normalizedId) >= 0))
            score = 150;

        if (score < 0)
            return -1;
        score += 50;
        if (!entry.noDisplay)
            score += 5;
        return score;
    }

    function _findEntry(rawId) {
        const candidates = _candidates(rawId);

        // Exact IDs are authoritative.
        for (let i = 0; i < candidates.length; i++) {
            try {
                const entry = DesktopEntries.byId(candidates[i]);
                if (entry)
                    return entry;
            } catch (e) {}
        }

        // Quickshell's heuristic lookup handles common startup/app ID forms.
        // Keep a no-icon result only as a final fallback: handler desktop
        // files (such as cc-switch-handler.desktop) can otherwise shadow the
        // real application entry that contains the icon.
        let heuristicWithoutIcon = null;
        for (let i = 0; i < candidates.length; i++) {
            try {
                const entry = DesktopEntries.heuristicLookup(candidates[i]);
                if (entry) {
                    if (_entryHasIcon(entry))
                        return entry;
                    if (!heuristicWithoutIcon)
                        heuristicWithoutIcon = entry;
                }
            } catch (e) {}
        }

        // Compare normalized desktop IDs. This covers values such as "Code"
        // vs "code.desktop" when the provider changes capitalization or
        // punctuation.
        const wanted = normalize(rawId);
        const entries = DesktopEntries.applications?.values || [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (entry && normalize(entry.id) === wanted)
                return entry;
        }

        // Last resort: restore the startupClass/id fuzzy matching used by the
        // original resolver. This is important for XWayland and apps whose
        // desktop filename is vendor-prefixed (for example CC Switch).
        const lookup = _key(rawId).replace(/\.desktop$/i, "");
        const normalizedLookup = _normalizedLookup(rawId);
        let bestEntry = null;
        let bestScore = -1;
        for (let i = 0; i < entries.length; i++) {
            const score = _scoreEntry(entries[i], lookup, normalizedLookup);
            if (score > bestScore) {
                bestEntry = entries[i];
                bestScore = score;
            }
        }
        if (bestEntry && bestScore >= 0)
            return bestEntry;
        if (heuristicWithoutIcon)
            return heuristicWithoutIcon;
        return null;
    }

    function _canonicalId(rawId, entry) {
        const value = String(entry?.id ?? rawId ?? "")
            .trim()
            .replace(/<\d+>$/, "");
        if (!value)
            return "";
        return /\.desktop$/i.test(value) ? value : value + ".desktop";
    }

    function resolve(rawId) {
        const raw = String(rawId ?? "").trim();
        const cacheKey = _key(raw);
        if (cacheKey && svc._cache[cacheKey])
            return svc._cache[cacheKey];

        const entry = _findEntry(raw);
        const desktopId = _canonicalId(raw, entry);
        const overrides = ConfigService.iconOverrides || ({});
        const override = overrides[desktopId] ?? overrides[raw] ?? "";
        const iconCandidates = [override, entry?.icon ?? "", raw];
        const candidates = _candidates(raw);
        for (let i = 0; i < candidates.length; i++)
            iconCandidates.push(candidates[i].replace(/\.desktop$/i, ""));

        let icon = "";
        for (let i = 0; i < iconCandidates.length; i++) {
            icon = _iconPath(iconCandidates[i]);
            if (icon)
                break;
        }
        if (!icon)
            icon = _iconPath("application-x-executable");

        const result = {
            desktopId: desktopId,
            normalizedId: normalize(desktopId),
            rawAppId: raw,
            name: entry?.name ?? raw,
            iconSource: icon,
            entry: entry,
        };
        if (cacheKey)
            svc._cache[cacheKey] = result;
        return result;
    }

    function canonicalId(rawId) {
        return resolve(rawId).desktopId;
    }

    function sameApp(left, right) {
        const a = typeof left === "object" ? left.desktopId : canonicalId(left);
        const b = typeof right === "object" ? right.desktopId : canonicalId(right);
        return !!a && !!b && normalize(a) === normalize(b);
    }

    function clearCache() {
        svc._cache = ({});
        svc.revision++;
    }

    property Connections _desktopEntryConnections: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            svc.clearCache();
        }
    }

    property Connections _configConnections: Connections {
        target: ConfigService
        function onIconOverridesChanged() {
            svc.clearCache();
        }
    }
}
