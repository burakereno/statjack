import AppKit
import SwiftUI

struct MenuBarMetricSegment: Equatable, Identifiable {
    let id: String
    let symbolName: String
    let text: String
    let width: CGFloat
}

enum MenuBarDisplay {
    static let statusHeight: CGFloat = 22
    static let horizontalPadding: CGFloat = 6
    static let iconOnlyWidth: CGFloat = 22
    static let metricIconWidth: CGFloat = 14
    static let iconTextSpacing: CGFloat = 2
    static let segmentSpacing: CGFloat = 6
    static let metricIconPointSize: CGFloat = 12
    static let metricTextPointSize: CGFloat = 12

    static let metricFont = NSFont.monospacedSystemFont(
        ofSize: metricTextPointSize,
        weight: .medium
    )

    static func showIconOnly(iconOnly: Bool, showCPU: Bool, showRAM: Bool, showNetwork: Bool) -> Bool {
        iconOnly || (!showCPU && !showRAM && !showNetwork)
    }

    static func metricSegments(
        iconOnly: Bool,
        showCPU: Bool,
        showRAM: Bool,
        showNetwork: Bool,
        cpu: String,
        ram: String,
        net: String
    ) -> [MenuBarMetricSegment] {
        guard !showIconOnly(
            iconOnly: iconOnly,
            showCPU: showCPU,
            showRAM: showRAM,
            showNetwork: showNetwork
        ) else { return [] }

        var segments: [MenuBarMetricSegment] = []
        if showCPU {
            segments.append(
                MenuBarMetricSegment(
                    id: "cpu",
                    symbolName: AppIcons.cpu,
                    text: cpu,
                    width: textSegmentWidth(for: cpu)
                )
            )
        }
        if showRAM {
            segments.append(
                MenuBarMetricSegment(
                    id: "ram",
                    symbolName: AppIcons.ram,
                    text: ram,
                    width: textSegmentWidth(for: ram)
                )
            )
        }
        if showNetwork {
            segments.append(
                MenuBarMetricSegment(
                    id: "network",
                    symbolName: AppIcons.network,
                    text: net,
                    width: textSegmentWidth(for: net)
                )
            )
        }
        return segments
    }

    static func textSegmentWidth(for text: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: metricFont]
        let textWidth = (text as NSString).size(withAttributes: attrs).width
        return ceil(metricIconWidth + iconTextSpacing + textWidth)
    }

    static func contentWidth(for segments: [MenuBarMetricSegment]) -> CGFloat {
        guard !segments.isEmpty else { return iconOnlyWidth }

        let segmentWidths = segments.reduce(CGFloat.zero) { $0 + $1.width }
        let spacings = CGFloat(max(segments.count - 1, 0)) * segmentSpacing
        return ceil(segmentWidths + spacings + (horizontalPadding * 2))
    }
}

struct MenuBarContentView: View {
    let iconOnly: Bool
    let showCPU: Bool
    let showRAM: Bool
    let showNetwork: Bool
    let cpu: String
    let ram: String
    let net: String

    private var showIconOnly: Bool {
        MenuBarDisplay.showIconOnly(
            iconOnly: iconOnly,
            showCPU: showCPU,
            showRAM: showRAM,
            showNetwork: showNetwork
        )
    }

    private var segments: [MenuBarMetricSegment] {
        MenuBarDisplay.metricSegments(
            iconOnly: iconOnly,
            showCPU: showCPU,
            showRAM: showRAM,
            showNetwork: showNetwork,
            cpu: cpu,
            ram: ram,
            net: net
        )
    }

    var body: some View {
        if showIconOnly {
            Image(systemName: AppIcons.app)
                .font(.system(size: 13))
                .frame(width: MenuBarDisplay.iconOnlyWidth, height: MenuBarDisplay.statusHeight)
        } else {
            HStack(spacing: MenuBarDisplay.segmentSpacing) {
                ForEach(segments) { segment in
                    HStack(spacing: MenuBarDisplay.iconTextSpacing) {
                        Image(systemName: segment.symbolName)
                            .font(.system(size: MenuBarDisplay.metricIconPointSize, weight: .medium))
                            .frame(width: MenuBarDisplay.metricIconWidth)
                        Text(segment.text)
                            .font(.system(
                                size: MenuBarDisplay.metricTextPointSize,
                                weight: .medium,
                                design: .monospaced
                            ))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(
                                width: segment.width
                                    - MenuBarDisplay.metricIconWidth
                                    - MenuBarDisplay.iconTextSpacing,
                                alignment: .leading
                            )
                    }
                    .frame(width: segment.width, alignment: .leading)
                }
            }
            .frame(width: MenuBarDisplay.contentWidth(for: segments), height: MenuBarDisplay.statusHeight)
        }
    }
}
