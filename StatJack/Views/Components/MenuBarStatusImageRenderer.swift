import AppKit

/// Draws fixed-width menu bar segments while safely reusing backing images.
@MainActor
final class MenuBarStatusImageRenderer {
    private var symbolCache: [String: NSImage] = [:]
    private var cachedImage: NSImage?

    private let symbolConfig = NSImage.SymbolConfiguration(
        pointSize: MenuBarDisplay.metricIconPointSize,
        weight: .medium
    )
    private let font = NSFont.monospacedSystemFont(
        ofSize: MenuBarDisplay.metricTextPointSize,
        weight: .medium
    )

    func image(for segments: [MenuBarMetricSegment]) -> NSImage {
        let width = MenuBarDisplay.contentWidth(for: segments)
        let height = MenuBarDisplay.statusHeight
        let size = NSSize(width: width, height: height)
        let image: NSImage

        if let cachedImage, cachedImage.size == size {
            image = cachedImage
        } else {
            image = NSImage(size: size)
            cachedImage = image
        }

        image.lockFocus()
        clearCanvas(width: width, height: height)
        draw(segments, canvasHeight: height)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func clearCanvas(width: CGFloat, height: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .copy
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func draw(_ segments: [MenuBarMetricSegment], canvasHeight: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        var x = MenuBarDisplay.horizontalPadding

        for segment in segments {
            drawSymbol(segment.symbolName, x: x, canvasHeight: canvasHeight)

            let textX = x + MenuBarDisplay.metricIconWidth + MenuBarDisplay.iconTextSpacing
            let textSize = (segment.text as NSString).size(withAttributes: attributes)
            let textY = floor((canvasHeight - textSize.height) / 2)
            (segment.text as NSString).draw(
                at: NSPoint(x: textX, y: textY),
                withAttributes: attributes
            )
            x += segment.width + MenuBarDisplay.segmentSpacing
        }
    }

    private func drawSymbol(_ symbolName: String, x: CGFloat, canvasHeight: CGFloat) {
        let symbol: NSImage
        if let cached = symbolCache[symbolName] {
            symbol = cached
        } else if let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(symbolConfig) {
            symbolCache[symbolName] = image
            symbol = image
        } else {
            return
        }

        let symbolSize = symbol.size
        let rect = NSRect(
            x: x + (MenuBarDisplay.metricIconWidth - symbolSize.width) / 2,
            y: (canvasHeight - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        symbol.draw(in: rect)
    }
}
