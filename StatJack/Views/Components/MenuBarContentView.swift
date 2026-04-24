import SwiftUI

struct MenuBarContentView: View {
    let iconOnly: Bool
    let showCPU: Bool
    let showRAM: Bool
    let showNetwork: Bool
    let cpu: String
    let ram: String
    let net: String

    private var showIconOnly: Bool {
        iconOnly || (!showCPU && !showRAM && !showNetwork)
    }

    var body: some View {
        if showIconOnly {
            Image(systemName: AppIcons.app)
                .font(.system(size: 13))
        } else {
            HStack(spacing: 6) {
                if showCPU {
                    HStack(spacing: 2) {
                        Image(systemName: AppIcons.cpu).font(.system(size: 10))
                        Text(cpu).font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
                if showRAM {
                    HStack(spacing: 2) {
                        Image(systemName: AppIcons.ram).font(.system(size: 10))
                        Text(ram).font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
                if showNetwork {
                    HStack(spacing: 2) {
                        Image(systemName: AppIcons.network).font(.system(size: 10))
                        Text(net).font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
            }
        }
    }
}
