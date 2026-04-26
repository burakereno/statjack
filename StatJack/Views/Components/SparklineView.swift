import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let color: Color
    var maxValue: Double? = nil
    var height: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if values.count >= 2 {
                    let path = sparklinePath(in: geo.size)
                    let fillPath = filledPath(from: path, height: geo.size.height)

                    fillPath
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    path
                        .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
    }

    private func sparklinePath(in size: CGSize) -> Path {
        let count = values.count
        let span = max(1, count - 1)
        let stepX = size.width / CGFloat(span)
        let upperBound = maxValue ?? max(values.max() ?? 1, 1)
        let bound = max(upperBound, 0.0001)

        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let normalized = min(max(value / bound, 0), 1)
            let y = size.height - CGFloat(normalized) * size.height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func filledPath(from line: Path, height: CGFloat) -> Path {
        var fill = line
        if let last = line.currentPoint {
            fill.addLine(to: CGPoint(x: last.x, y: height))
            fill.addLine(to: CGPoint(x: 0, y: height))
            fill.closeSubpath()
        }
        return fill
    }
}
