import QtQuick
import qs.modules.dock

Canvas {
    id: root

    property var values: []
    property color lineColor: ThemeService.accentColor
    // Memory usage normally varies by far less than one percent. Scale that
    // graph to its observed range so genuine small changes remain visible.
    property bool adaptiveRange: false

    implicitHeight: 36
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (values.length < 2 || width <= 0 || height <= 0)
            return

        const inset = 2
        const plotWidth = width - inset * 2
        const plotHeight = height - inset * 2
        let low = 0
        let high = 1
        if (adaptiveRange) {
            low = values[0]
            high = values[0]
            for (let i = 1; i < values.length; ++i) {
                low = Math.min(low, values[i])
                high = Math.max(high, values[i])
            }
            if (high - low < 0.01) {
                const middle = (high + low) / 2
                low = Math.max(0, middle - 0.005)
                high = Math.min(1, middle + 0.005)
            }
        }
        ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.24)
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(inset, height - inset)
        ctx.lineTo(width - inset, height - inset)
        ctx.stroke()

        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        for (let i = 0; i < values.length; ++i) {
            const x = inset + plotWidth * i / (values.length - 1)
            const ratio = (values[i] - low) / (high - low)
            const y = inset + plotHeight * (1 - Math.max(0, Math.min(1, ratio)))
            if (i === 0)
                ctx.moveTo(x, y)
            else
                ctx.lineTo(x, y)
        }
        ctx.stroke()
    }
    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
