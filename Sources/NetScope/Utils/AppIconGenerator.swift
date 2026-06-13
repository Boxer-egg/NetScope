import AppKit

enum AppIconGenerator {
    static func generate(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let ctx = NSGraphicsContext.current!.cgContext

        // ── Background: bright blue → deep indigo (top-left to bottom-right) ──
        let bgGrad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedRed: 0.25, green: 0.55, blue: 1.00, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.05, green: 0.16, blue: 0.65, alpha: 1).cgColor,
            ] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(bgGrad,
            start: CGPoint(x: 0,    y: size),
            end:   CGPoint(x: size, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // ── Soft highlight (upper-left glow) ──
        let hlGrad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.white.withAlphaComponent(0.20).cgColor,
                NSColor.white.withAlphaComponent(0.00).cgColor,
            ] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawRadialGradient(hlGrad,
            startCenter: CGPoint(x: size * 0.28, y: size * 0.74),
            startRadius: 0,
            endCenter:   CGPoint(x: size * 0.28, y: size * 0.74),
            endRadius:   size * 0.50,
            options: [])

        // ── Layout ──
        let hub = CGPoint(x: size * 0.50, y: size * 0.50)
        let r   = size * 0.260

        // Three satellite nodes: top-left, right, bottom
        let sats = [
            CGPoint(x: hub.x - r * 0.82, y: hub.y + r * 0.72),
            CGPoint(x: hub.x + r * 1.00, y: hub.y + r * 0.08),
            CGPoint(x: hub.x - r * 0.08, y: hub.y - r * 0.96),
        ]

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Arcs — subtle drop-shadow pass (offset copy)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.14).cgColor)
        ctx.setLineWidth(size * 0.028)
        for sat in sats {
            let off = size * 0.005
            let p = CGMutablePath()
            p.move(to: CGPoint(x: hub.x, y: hub.y - off))
            p.addQuadCurve(
                to:      CGPoint(x: sat.x, y: sat.y - off),
                control: controlPt(hub, sat, 0.18, offset: CGPoint(x: 0, y: -off)))
            ctx.addPath(p); ctx.strokePath()
        }

        // Arcs — white
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.90).cgColor)
        ctx.setLineWidth(size * 0.022)
        for sat in sats {
            let p = CGMutablePath()
            p.move(to: hub)
            p.addQuadCurve(to: sat, control: controlPt(hub, sat, 0.18))
            ctx.addPath(p); ctx.strokePath()
        }

        // ── Satellite nodes ──
        let sr = size * 0.050
        for sat in sats {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.010),
                          blur: size * 0.026,
                          color: NSColor.black.withAlphaComponent(0.28).cgColor)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.90).cgColor)
            ctx.addEllipse(in: CGRect(x: sat.x - sr, y: sat.y - sr, width: sr * 2, height: sr * 2))
            ctx.fillPath()
            ctx.restoreGState()
        }

        // ── Hub node: white disc + blue inner dot ──
        let hr = size * 0.082
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.016),
                      blur: size * 0.040,
                      color: NSColor.black.withAlphaComponent(0.36).cgColor)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.addEllipse(in: CGRect(x: hub.x - hr, y: hub.y - hr, width: hr * 2, height: hr * 2))
        ctx.fillPath()
        ctx.restoreGState()

        let ir = size * 0.042
        ctx.setFillColor(NSColor(calibratedRed: 0.22, green: 0.52, blue: 1.0, alpha: 1).cgColor)
        ctx.addEllipse(in: CGRect(x: hub.x - ir, y: hub.y - ir, width: ir * 2, height: ir * 2))
        ctx.fillPath()

        image.unlockFocus()

        // ── Squircle clip (22.5% corner radius — macOS standard) ──
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225).setClip()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        out.unlockFocus()
        return out
    }

    /// Perpendicular control point for a gentle outward quadratic arc.
    private static func controlPt(_ a: CGPoint, _ b: CGPoint, _ curvature: CGFloat,
                                   offset: CGPoint = .zero) -> CGPoint {
        let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
        let dx = b.x - a.x, dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return CGPoint(x: mx + offset.x, y: my + offset.y) }
        return CGPoint(
            x: mx - (dy / len) * len * curvature + offset.x,
            y: my + (dx / len) * len * curvature + offset.y
        )
    }
}
