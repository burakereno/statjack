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
    static let horizontalPadding: CGFloat = 4
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

    static func showIconOnly(
        iconOnly: Bool,
        showCPU: Bool,
        showRAM: Bool,
        showDisk: Bool,
        showNetwork: Bool,
        showGPU: Bool,
        showTemperature: Bool
    ) -> Bool {
        iconOnly || (!showCPU && !showRAM && !showDisk && !showNetwork && !showGPU && !showTemperature)
    }

    static func metricSegments(
        iconOnly: Bool,
        showCPU: Bool,
        showRAM: Bool,
        showDisk: Bool,
        showNetwork: Bool,
        showGPU: Bool,
        showTemperature: Bool,
        cpu: String,
        ram: String,
        disk: String,
        net: String,
        gpu: String,
        temp: String
    ) -> [MenuBarMetricSegment] {
        guard !showIconOnly(
            iconOnly: iconOnly,
            showCPU: showCPU,
            showRAM: showRAM,
            showDisk: showDisk,
            showNetwork: showNetwork,
            showGPU: showGPU,
            showTemperature: showTemperature
        ) else { return [] }

        var segments: [MenuBarMetricSegment] = []
        if showCPU {
            segments.append(MenuBarMetricSegment(
                id: "cpu", symbolName: AppIcons.cpu, text: cpu,
                width: textSegmentWidth(for: cpu)
            ))
        }
        if showRAM {
            segments.append(MenuBarMetricSegment(
                id: "ram", symbolName: AppIcons.ram, text: ram,
                width: textSegmentWidth(for: ram)
            ))
        }
        if showDisk {
            segments.append(MenuBarMetricSegment(
                id: "disk", symbolName: AppIcons.disk, text: disk,
                width: textSegmentWidth(for: disk)
            ))
        }
        if showNetwork {
            segments.append(MenuBarMetricSegment(
                id: "network", symbolName: AppIcons.network, text: net,
                width: textSegmentWidth(for: net)
            ))
        }
        if showGPU {
            segments.append(MenuBarMetricSegment(
                id: "gpu", symbolName: AppIcons.gpu, text: gpu,
                width: textSegmentWidth(for: gpu)
            ))
        }
        if showTemperature {
            segments.append(MenuBarMetricSegment(
                id: "temp", symbolName: AppIcons.temperature, text: temp,
                width: textSegmentWidth(for: temp)
            ))
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
    let showDisk: Bool
    let showNetwork: Bool
    let cpu: String
    let ram: String
    let disk: String
    let net: String

    private var showIconOnly: Bool {
        MenuBarDisplay.showIconOnly(
            iconOnly: iconOnly,
            showCPU: showCPU,
            showRAM: showRAM,
            showDisk: showDisk,
            showNetwork: showNetwork,
            showGPU: false,
            showTemperature: false
        )
    }

    private var segments: [MenuBarMetricSegment] {
        MenuBarDisplay.metricSegments(
            iconOnly: iconOnly,
            showCPU: showCPU,
            showRAM: showRAM,
            showDisk: showDisk,
            showNetwork: showNetwork,
            showGPU: false,
            showTemperature: false,
            cpu: cpu,
            ram: ram,
            disk: disk,
            net: net,
            gpu: "",
            temp: ""
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
