pragma Singleton
import QtQuick

// Visual attachment points only. Feature modules keep ownership of their
// content and state; hosts do not need to import or instantiate them.
QtObject {
    property var _hosts: []

    function registerHost(host) {
        if (_hosts.indexOf(host) === -1)
            _hosts = _hosts.concat([host])
    }

    function unregisterHost(host) {
        _hosts = _hosts.filter(entry => entry !== host)
    }

    function overlayFor(screen) {
        if (!screen)
            return null
        for (let i = 0; i < _hosts.length; ++i) {
            const host = _hosts[i]
            if (host.screen === screen)
                return host
        }
        return null
    }
}
