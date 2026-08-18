import QtQuick

Item {
    id: root

    // ── Inputs (set by parent PanelWindow) ──
    required property var screenTexture     // full-screen ShaderEffectSource
    required property size screenSize       // screen pixel dimensions
    property real panelScreenX: 0           // panel position on screen (px)
    property real panelScreenY: 0

    // ── Shape ──
    // 圆角半径（像素）。0=直角，越大越圆。
    // 会被自动 clamp 到不超过面板最短边的一半。
    property int cornerRadius: 5

    // ── Refraction 折射（液态玻璃的核心：背景扭曲） ──
    // 折射强度。0=关闭（完全透明无扭曲），越大扭曲越强。
    // 调整范围建议 0.0 ~ 1.0
    property real factor: 0.8
    // 折射衰减曲线指数。控制扭曲从边缘向中心衰减的速度：
    //   低值 (2~8)：  扭曲平缓地向中心渗透，整体柔和
    //   高值 (16~24)：扭曲集中在边缘附近，中心区域几乎不变形
    // 太高会导致扭曲"缩"成一条极细的边线。
    property real powFactor: 16

    // ── Noise dither 噪点抖动（模拟磨砂玻璃的颗粒感） ──
    // 噪点强度。0=完全光滑，越大颗粒感越重。
    // 调整范围建议 0.0 ~ 0.15
    property real noise: 0.06

    // ── Glow / rim light 边缘发光（玻璃边缘的高光） ──
    // 发光整体强度。0=无发光，1=最强发光。
    property real glowWeight: 0.38
    // 发光偏置。影响 glow 叠加到底色上的方式：
    //   正值：整体提亮（过曝感）
    //   负值：整体压暗，让发光更突出（推荐 -0.05 ~ -0.15）
    property real glowBias: -0.097
    // 发光边缘范围控制（smoothstep 的两个边界）：
    //   glowEdge0: 发光开始出现的距离（越大发光区域越窄）
    //   glowEdge1: 发光达到最大值的距离（通常设为负值以在边缘内侧就亮起）
    //   典型值：edge0=0.5, edge1=-0.5 产生从边缘向内渐隐的发光
    property real glowEdge0: 0.5
    property real glowEdge1: -0.5
    // 发光聚焦模式。0=纯径向（从中心均匀向外），1=纯方向性（单侧光源）
    // 中间值混合两者。配合 glowAngle 使用。
    property real glowFocus: 0.0
    // 光源方向（角度制）。0°=右侧，90°=上方，180°=左侧，270°=下方
    // 仅在 glowFocus > 0 时有效。
    property real glowAngle: 90
    // 发光图案模式：
    //   0 = 正弦波纹（同心圆环纹理，类似指纹/涟漪）
    //   1 = 方向性渐变（模拟单侧光源照射的边缘反光）
    property int glowPattern: 1

    // ── Color 颜色叠加 ──
    // 面板整体色调（RGBA）。与背景像素逐分量相乘：
    //   (1,1,1,1) = 保持背景原色（无色偏）
    //   (0.9,0.95,1.0,1.0) = 轻微蓝白调
    //   (0.8,0.9,1.0,0.8) = 半透明蓝玻璃
    property vector4d color: Qt.vector4d(1.0, 1.0, 1.0, 1.0)
    // 发光颜色（RGBA）。RGB 控制发光色调，A 控制发光透明度：
    //   (1,1,1,0.5) = 白色半透明发光（最自然）
    //   (0.5,0.8,1.0,0.6) = 蓝色发光
    //   A 设为 0 可完全关闭发光
    property vector4d glowColor: Qt.vector4d(1.0, 1.0, 1.0, 0.5)

    // ═══════════════════════════════════════════════════════════
    // ShaderEffect — uniform order MUST match the fragment shader
    // ═══════════════════════════════════════════════════════════

    ShaderEffect {
        anchors.fill: parent

        // sampler2D (binding 1)
        property var u_in: root.screenTexture

        // uniform block (binding 0) — must match .frag declaration order
        property real u_noise: root.noise
        property real u_glowWeight: root.glowWeight
        property real u_glowBias: root.glowBias
        property real u_glowEdge0: root.glowEdge0
        property real u_glowEdge1: root.glowEdge1
        property real u_glowFocus: root.glowFocus
        property real u_glowAngle: root.glowAngle * Math.PI / 180.0
        property real u_powFactor: root.powFactor
        property real u_factor: root.factor
        property int u_cornerRadius: root.cornerRadius
        property int u_glowPattern: root.glowPattern
        property vector2d u_screenResolution:
            Qt.vector2d(root.screenSize.width, root.screenSize.height)
        property vector2d u_panelPosition:
            Qt.vector2d(root.panelScreenX, root.panelScreenY)
        property vector2d u_panelSize:
            Qt.vector2d(root.width, root.height)
        property vector4d u_color: root.color
        property vector4d u_glowColor: root.glowColor

        vertexShader: Qt.resolvedUrl("../shaders/liquid.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../shaders/liquid.frag.qsb")
    }

    // ── Border overlay ──

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border {
            width: 1
            color: Qt.rgba(1, 1, 1, 0.30)
        }
    }

    // ── Top highlight ──

    Rectangle {
        width: parent.width * 0.4
        height: 2
        anchors {
            top: parent.top
            topMargin: 2
            horizontalCenter: parent.horizontalCenter
        }
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.40)
    }
}
