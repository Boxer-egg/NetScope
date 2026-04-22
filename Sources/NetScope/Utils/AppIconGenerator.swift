import AppKit

enum AppIconGenerator {
    static func generate(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let context = NSGraphicsContext.current!.cgContext

        // Background gradient
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedRed: 0.12, green: 0.36, blue: 0.85, alpha: 1.0).cgColor,
                NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.60, alpha: 1.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: size * 0.35, y: size * 0.65),
            startRadius: 0,
            endCenter: CGPoint(x: size * 0.5, y: size * 0.5),
            endRadius: size * 0.7,
            options: []
        )

        // Draw globe arcs
        let center = CGPoint(x: size * 0.5, y: size * 0.5)
        let globeRadius = size * 0.28
        let lineWidth = size * 0.025

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)

        // Horizontal arc
        let horizontalArc = CGMutablePath()
        horizontalArc.addArc(center: center, radius: globeRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.addPath(horizontalArc)
        context.strokePath()

        // Vertical ellipse
        let verticalPath = CGMutablePath()
        verticalPath.addEllipse(in: CGRect(
            x: center.x - globeRadius * 0.35,
            y: center.y - globeRadius,
            width: globeRadius * 0.7,
            height: globeRadius * 2
        ))
        context.addPath(verticalPath)
        context.strokePath()

        // Additional arcs for 3D effect
        for angle in [CGFloat.pi / 4, -CGFloat.pi / 4] {
            let arcPath = CGMutablePath()
            let transform = CGAffineTransform(rotationAngle: angle).translatedBy(x: center.x, y: center.y)
            arcPath.addEllipse(in: CGRect(
                x: -globeRadius * 0.35,
                y: -globeRadius,
                width: globeRadius * 0.7,
                height: globeRadius * 2
            ), transform: transform)
            context.addPath(arcPath)
            context.strokePath()
        }

        // Connection nodes
        let nodePositions: [(CGFloat, CGFloat)] = [
            (0.35, 0.55),
            (0.65, 0.45),
            (0.50, 0.72),
            (0.42, 0.35),
            (0.58, 0.60)
        ]

        let nodeRadius = size * 0.035
        context.setFillColor(NSColor.white.cgColor)

        for (nx, ny) in nodePositions {
            let point = CGPoint(x: size * nx, y: size * ny)
            context.addEllipse(in: CGRect(
                x: point.x - nodeRadius,
                y: point.y - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            ))
            context.fillPath()
        }

        // Connection lines between nodes
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(size * 0.018)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let lines = [
            (nodePositions[0], nodePositions[1]),
            (nodePositions[1], nodePositions[2]),
            (nodePositions[2], nodePositions[4]),
            (nodePositions[4], nodePositions[3]),
            (nodePositions[3], nodePositions[0])
        ]

        for (start, end) in lines {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: size * start.0, y: size * start.1))
            path.addLine(to: CGPoint(x: size * end.0, y: size * end.1))
            context.addPath(path)
            context.strokePath()
        }

        // Rounded rect clip
        image.unlockFocus()

        // Apply rounded corners
        let roundedImage = NSImage(size: NSSize(width: size, height: size))
        roundedImage.lockFocus()
        let cornerRadius = size * 0.22
        let clipPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        clipPath.setClip()
        image.draw(in: rect, from: NSRect(x: 0, y: 0, width: size, height: size), operation: .sourceOver, fraction: 1.0)
        roundedImage.unlockFocus()

        return roundedImage
    }
}
