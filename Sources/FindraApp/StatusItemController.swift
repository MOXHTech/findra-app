import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var onOpen: (() -> Void)?
    private var observesAppearance = false

    func configure(onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
        guard let button = statusItem.button else { return }
        updateImage()
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(openFindra)
        if !observesAppearance {
            observesAppearance = true
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(systemAppearanceChanged),
                name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil
            )
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func openFindra() {
        onOpen?()
    }

    @objc private func systemAppearanceChanged() {
        updateImage()
    }

    private func updateImage() {
        guard let button = statusItem.button else { return }
        button.image = Self.makeStatusTemplateImage(side: 18)
    }

    static func makeStatusTemplateImage(side: CGFloat) -> NSImage {
        let size = NSSize(width: side, height: side)
        let scale = side / 18
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let center = NSPoint(x: rect.midX - 0.3 * scale, y: rect.midY - 0.1 * scale)
            strokeArc(center: center, radius: 5.4 * scale, start: 145, end: 382, color: .black, width: 1.75 * scale)
            strokeArc(center: center, radius: 5.4 * scale, start: -40, end: 90, color: .black, width: 1.75 * scale)
            strokeArc(center: center, radius: 3.0 * scale, start: 202, end: 496, color: .black, width: 1.35 * scale)
            strokeArc(center: center, radius: 3.0 * scale, start: 20, end: 165, color: .black, width: 1.35 * scale)
            dot(at: NSPoint(x: rect.midX - 2.4 * scale, y: rect.midY - 2.2 * scale), radius: 0.85 * scale, color: .black)
            dot(at: NSPoint(x: rect.midX + 2.0 * scale, y: rect.midY + 2.1 * scale), radius: 0.8 * scale, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Findra"
        return image
    }

    private static func strokeArc(center: NSPoint, radius: CGFloat, start: CGFloat, end: CGFloat, color: NSColor, width: CGFloat) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private static func dot(at center: NSPoint, radius: CGFloat, color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
    }
}
