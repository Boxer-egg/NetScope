import SwiftUI

/// Mirrored throughput sparkline: download grows up from the middle axis,
/// upload grows down. Drawn with Canvas so hundreds of samples stay cheap.
struct TrafficSparkline: View {
    let samples: [ConnectionStore.RateSample]

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }

            let down = samples.map { Double($0.bytesIn) }
            let up = samples.map { Double($0.bytesOut) }
            let peak = max(down.max() ?? 1, up.max() ?? 1, 1)

            let midY = size.height / 2
            let stepX = size.width / CGFloat(samples.count - 1)
            let half = midY - 2

            var downPath = Path()
            var upPath = Path()
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * stepX
                let downY = midY - CGFloat(Double(sample.bytesIn) / peak) * half
                let upY = midY + CGFloat(Double(sample.bytesOut) / peak) * half
                if index == 0 {
                    downPath.move(to: CGPoint(x: x, y: downY))
                    upPath.move(to: CGPoint(x: x, y: upY))
                } else {
                    downPath.addLine(to: CGPoint(x: x, y: downY))
                    upPath.addLine(to: CGPoint(x: x, y: upY))
                }
            }

            context.stroke(
                downPath,
                with: .color(.blue.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                upPath,
                with: .color(.red.opacity(0.7)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )

            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: midY))
            axis.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(axis, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5))
        }
    }
}
