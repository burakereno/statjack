import AppKit
import SwiftUI

struct PublicIPRow: View {
    @Bindable private var service = PublicIPService.shared
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            Text("PUBLIC IP")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Group {
                if let ip = service.publicIP {
                    Text(ip)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if service.isFetching {
                    Text("Loading…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(service.lastError ?? "Unavailable")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if service.publicIP != nil {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(copied ? Color.green : Color.secondary.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.04))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let ip = service.publicIP else {
                service.refresh()
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ip, forType: .string)
            withAnimation(.snappy(duration: 0.18)) { copied = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.snappy(duration: 0.18)) { copied = false }
            }
        }
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .help(service.publicIP != nil ? "Click to copy" : "Click to retry")
        .onAppear { service.fetchIfNeeded() }
    }
}
