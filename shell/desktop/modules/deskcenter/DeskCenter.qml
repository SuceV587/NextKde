import QtQuick
import Quickshell
import qs.desktop.modules.common

// 修复多屏：为所有连接的显示器挂载桌面层，实现三屏右键菜单 100% 绝对统一
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: Component {
            DeskCenterWindow {
                required property var modelData
                screen: modelData
                visible: ScreenLifecycle.outputAvailable && modelData !== null
            }
        }
    }
}
