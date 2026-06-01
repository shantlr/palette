import AppKit
import CoreGraphics
import SwiftUI

enum ScreenBrushCropGeometry {
    static func pixelCropRect(imageSize: NSSize, cropRect: NSRect, scale: CGFloat) -> CGRect {
        let scaledHeight = imageSize.height * scale

        return CGRect(
            x: cropRect.origin.x * scale,
            y: scaledHeight - ((cropRect.origin.y + cropRect.height) * scale),
            width: cropRect.width * scale,
            height: cropRect.height * scale
        ).integral
    }
}

struct ScreenBrushScreenDescriptor: Equatable {
    let displayID: CGDirectDisplayID?
    let frame: NSRect
    let visibleFrame: NSRect
    let backingScaleFactor: CGFloat
}

enum ScreenBrushTargetGeometry {
    static func focusedScreen(
        at point: NSPoint,
        screens: [ScreenBrushScreenDescriptor],
        fallback: ScreenBrushScreenDescriptor?
    ) -> ScreenBrushScreenDescriptor? {
        screens.first(where: { $0.frame.contains(point) }) ?? fallback ?? screens.first
    }

    static func defaultCaptureRect(focusedScreenFrame: NSRect, unionFrame: NSRect) -> NSRect {
        NSRect(
            x: focusedScreenFrame.origin.x - unionFrame.origin.x,
            y: focusedScreenFrame.origin.y - unionFrame.origin.y,
            width: focusedScreenFrame.width,
            height: focusedScreenFrame.height
        )
    }

    static func toolbarFrame(
        toolbarSize: NSSize,
        focusedVisibleFrame: NSRect,
        unionFrame: NSRect,
        inset: CGFloat = 24
    ) -> NSRect {
        let minX = focusedVisibleFrame.minX - unionFrame.minX + inset
        let maxX = focusedVisibleFrame.maxX - unionFrame.minX - toolbarSize.width - inset
        let originX = min(max((focusedVisibleFrame.midX - unionFrame.minX) - toolbarSize.width / 2, minX), maxX)
        let originY = focusedVisibleFrame.maxY - unionFrame.minY - toolbarSize.height - inset

        return NSRect(x: originX, y: originY, width: toolbarSize.width, height: toolbarSize.height)
    }

    static func previewOrigin(
        panelSize: NSSize,
        focusedVisibleFrame: NSRect,
        inset: CGFloat = 20
    ) -> NSPoint {
        NSPoint(
            x: focusedVisibleFrame.maxX - panelSize.width - inset,
            y: focusedVisibleFrame.minY + inset
        )
    }
}

@MainActor
final class ScreenBrushController: NSObject {
    private var panel: ScreenBrushOverlayPanel?
    private var isCursorHidden = false
    private let previewController = ScreenBrushPreviewController()

    var isActive: Bool {
        panel?.isVisible == true
    }

    func toggle() {
        if isActive {
            finishCapture()
        } else {
            start()
        }
    }

    func cancel() {
        closeOverlay(restoreCursor: true)
    }

    private func start() {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            NSSound.beep()
            return
        }

        let panel = ScreenBrushOverlayPanel(controller: self)
        self.panel = panel
        panel.show()
        hideCursor()
    }

    private func finishCapture() {
        guard let panel else { return }

        panel.prepareForCapture()
        let windowNumber = panel.windowNumber
        let unionFrame = panel.unionFrame
        let renderScale = panel.renderScale
        let drawing = panel.drawingImage(scale: renderScale)
        let cropRect = panel.captureRect ?? panel.defaultCaptureRect
        let focusedVisibleFrame = panel.focusedVisibleFrame
        panel.hideFromScreen()
        self.panel = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            defer { self.restoreCursorIfNeeded() }

            await self.waitUntilWindowLeavesScreen(windowNumber)

            guard let screenshot = self.captureDesktopImage(in: unionFrame, scale: renderScale) else {
                NSSound.beep()
                return
            }

            let finalImage = self.composite(base: screenshot, overlay: drawing, size: unionFrame.size)
            let croppedImage = self.crop(image: finalImage, to: cropRect, scale: renderScale)
            self.writeToPasteboard(croppedImage)
            let savedURL = self.saveImage(croppedImage)
            self.previewController.show(image: croppedImage, fileURL: savedURL, focusedVisibleFrame: focusedVisibleFrame)
        }
    }

    private func closeOverlay(restoreCursor: Bool) {
        panel?.close()
        panel = nil

        if restoreCursor {
            restoreCursorIfNeeded()
        }
    }

    private func hideCursor() {
        guard !isCursorHidden else { return }
        NSCursor.hide()
        isCursorHidden = true
    }

    private func restoreCursorIfNeeded() {
        guard isCursorHidden else { return }
        NSCursor.unhide()
        isCursorHidden = false
    }

    private func captureDesktopImage(in unionFrame: NSRect, scale: CGFloat) -> NSImage? {
        guard let image = renderImage(size: unionFrame.size, scale: scale, draw: { _ in
            for screen in NSScreen.screens {
                guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                      let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.uint32Value)) else {
                    return false
                }

                let drawRect = NSRect(
                    x: screen.frame.origin.x - unionFrame.origin.x,
                    y: screen.frame.origin.y - unionFrame.origin.y,
                    width: screen.frame.width,
                    height: screen.frame.height
                )
                NSGraphicsContext.current?.imageInterpolation = .high
                NSImage(cgImage: cgImage, size: drawRect.size).draw(in: drawRect)
            }

            return true
        }) else {
            return nil
        }

        return image
    }

    private func composite(base: NSImage, overlay: NSImage, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size))
        overlay.draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    private func crop(image: NSImage, to rect: NSRect, scale: CGFloat) -> NSImage {
        let clippedRect = rect.intersection(NSRect(origin: .zero, size: image.size))
        guard !clippedRect.isEmpty else { return image }

        let scaledRect = ScreenBrushCropGeometry.pixelCropRect(
            imageSize: image.size,
            cropRect: clippedRect,
            scale: scale
        )

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cropped = cgImage.cropping(to: scaledRect) else {
            return image
        }

        return NSImage(cgImage: cropped, size: clippedRect.size)
    }

    private func writeToPasteboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    private func saveImage(_ image: NSImage) -> URL? {
        guard let pngData = encodePNG(image) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let fileName = "palette_\(formatter.string(from: Date())).png"
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent(fileName)

        do {
            try pngData.write(to: desktopURL)
            let optimizationResult = PNGOptimizer.optimizeIfAvailable(fileURL: desktopURL)
            previewController.lastOptimizationResult = optimizationResult
            return desktopURL
        } catch {
            print("Failed to save screen brush capture: \(error.localizedDescription)")
            return nil
        }
    }

    private func renderImage(size: NSSize, scale: CGFloat, draw: (CGContext) -> Bool) -> NSImage? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(Int(size.width * scale), 1),
            pixelsHigh: max(Int(size.height * scale), 1),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let bitmap,
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: scale, y: scale)

        let completed = draw(context.cgContext)

        NSGraphicsContext.restoreGraphicsState()
        guard completed else { return nil }

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private func waitUntilWindowLeavesScreen(_ windowNumber: Int) async {
        for _ in 0..<20 {
            let visibleWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
            let windowStillVisible = visibleWindows?.contains(where: {
                ($0[kCGWindowNumber as String] as? Int) == windowNumber
            }) == true

            if !windowStillVisible {
                return
            }

            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class ScreenBrushOverlayPanel: NSPanel {
    let unionFrame: NSRect
    let renderScale: CGFloat
    let defaultCaptureRect: NSRect
    let focusedVisibleFrame: NSRect
    var captureRect: NSRect? {
        canvasView.captureRect
    }

    private let rootView: ScreenBrushRootView
    private let canvasView: ScreenBrushCanvasView
    private let toolbarModel = ScreenBrushToolbarModel()

    init(controller: ScreenBrushController) {
        let unionFrame = NSScreen.screens.map(\.frame).reduce(into: NSRect.null) { partial, frame in
            partial = partial.union(frame)
        }
        let screens = NSScreen.screens.map { screen in
            ScreenBrushScreenDescriptor(
                displayID: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map {
                    CGDirectDisplayID($0.uint32Value)
                },
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                backingScaleFactor: screen.backingScaleFactor
            )
        }
        let fallbackScreen = NSScreen.main.map { screen in
            ScreenBrushScreenDescriptor(
                displayID: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map {
                    CGDirectDisplayID($0.uint32Value)
                },
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                backingScaleFactor: screen.backingScaleFactor
            )
        }
        let focusedScreen = ScreenBrushTargetGeometry.focusedScreen(
            at: NSEvent.mouseLocation,
            screens: screens,
            fallback: fallbackScreen
        ) ?? ScreenBrushScreenDescriptor(
            displayID: nil,
            frame: unionFrame,
            visibleFrame: unionFrame,
            backingScaleFactor: NSScreen.main?.backingScaleFactor ?? 1
        )

        self.unionFrame = focusedScreen.frame
        self.renderScale = focusedScreen.backingScaleFactor
        self.defaultCaptureRect = ScreenBrushTargetGeometry.defaultCaptureRect(
            focusedScreenFrame: focusedScreen.frame,
            unionFrame: focusedScreen.frame
        )
        self.focusedVisibleFrame = focusedScreen.visibleFrame
        self.canvasView = ScreenBrushCanvasView(frame: NSRect(origin: .zero, size: focusedScreen.frame.size), toolbarModel: toolbarModel)
        self.rootView = ScreenBrushRootView(
            frame: NSRect(origin: .zero, size: focusedScreen.frame.size),
            canvasView: canvasView,
            toolbarModel: toolbarModel,
            focusedVisibleFrame: focusedScreen.visibleFrame,
            unionFrame: focusedScreen.frame
        )

        super.init(
            contentRect: focusedScreen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        acceptsMouseMovedEvents = true
        contentView = rootView
        initialFirstResponder = canvasView
        canvasView.onCancel = { [weak controller] in
            controller?.cancel()
        }
        canvasView.onCapture = { [weak controller] in
            controller?.toggle()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func show() {
        orderFrontRegardless()
        makeKey()
        makeFirstResponder(canvasView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func drawingImage(scale: CGFloat) -> NSImage {
        canvasView.drawingImage(scale: scale)
    }

    func prepareForCapture() {
        canvasView.hideCaptureDecorations()
    }

    func hideFromScreen() {
        orderOut(nil)
        contentView?.displayIfNeeded()
    }
}

@MainActor
private final class ScreenBrushRootView: NSView {
    private let canvasView: ScreenBrushCanvasView
    private let toolbarView: NSHostingView<ScreenBrushToolbarView>
    private let focusedVisibleFrame: NSRect
    private let unionFrame: NSRect

    init(
        frame frameRect: NSRect,
        canvasView: ScreenBrushCanvasView,
        toolbarModel: ScreenBrushToolbarModel,
        focusedVisibleFrame: NSRect,
        unionFrame: NSRect
    ) {
        self.canvasView = canvasView
        self.toolbarView = NSHostingView(rootView: ScreenBrushToolbarView(model: toolbarModel))
        self.focusedVisibleFrame = focusedVisibleFrame
        self.unionFrame = unionFrame
        super.init(frame: frameRect)

        wantsLayer = true
        addSubview(canvasView)
        addSubview(toolbarView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        canvasView.frame = bounds

        let toolbarSize = toolbarView.fittingSize
        toolbarView.frame = ScreenBrushTargetGeometry.toolbarFrame(
            toolbarSize: toolbarSize,
            focusedVisibleFrame: focusedVisibleFrame,
            unionFrame: unionFrame
        )
    }
}

@MainActor
private final class ScreenBrushToolbarModel: ObservableObject {
    private static let brushSizeDefaultsKey = "screenBrush.brushSize"

    @Published var brushSize: Double {
        didSet {
            UserDefaults.standard.set(brushSize, forKey: Self.brushSizeDefaultsKey)
        }
    }
    @Published var isSelectingArea = true
    @Published var hasSelection = false

    init() {
        let savedBrushSize = UserDefaults.standard.object(forKey: Self.brushSizeDefaultsKey) as? Double
        brushSize = savedBrushSize ?? 6
    }

    var brushLabel: String {
        "Brush \(Int(brushSize.rounded()))"
    }
}

private struct ScreenBrushToolbarView: View {
    @ObservedObject var model: ScreenBrushToolbarModel

    var body: some View {
        HStack(spacing: 14) {
            Button(model.isSelectingArea ? "Selecting Area..." : "Select Area") {
                model.isSelectingArea.toggle()
            }
            .buttonStyle(.borderedProminent)

            if model.hasSelection {
                Text("Crop active")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(model.brushLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Slider(value: $model.brushSize, in: 2...24, step: 2)
                    .frame(width: 140)
            }

            Text(model.isSelectingArea ? "Drag rectangle. C capture. Esc cancel." : "Draw. S select area. C capture. Esc cancel.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.15))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

@MainActor
private final class ScreenBrushCanvasView: NSView {
    struct Stroke {
        var points: [CGPoint]
        var width: CGFloat
    }

    var onCancel: (() -> Void)?
    var onCapture: (() -> Void)?
    var captureRect: NSRect?

    private let toolbarModel: ScreenBrushToolbarModel
    private var strokes: [Stroke] = []
    private var currentStroke: Stroke?
    private var cursorPoint: CGPoint?
    private var selectionStartPoint: CGPoint?
    private var hidesCaptureDecorations = false
    private let strokeColor = NSColor.systemRed.withAlphaComponent(0.9)
    private let cursorFillColor = NSColor.systemRed.withAlphaComponent(0.35)
    private var trackingAreaRef: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    init(frame frameRect: NSRect, toolbarModel: ScreenBrushToolbarModel) {
        self.toolbarModel = toolbarModel
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingAreaRef = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingAreaRef)
        self.trackingAreaRef = trackingAreaRef
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: toolbarModel.isSelectingArea ? .crosshair : .crosshair)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z" {
            undoLastStroke()
            return
        }

        if let characters = event.charactersIgnoringModifiers?.lowercased() {
            switch characters {
            case "s":
                toolbarModel.isSelectingArea = true
                needsDisplay = true
                return
            case "c":
                onCapture?()
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        cursorPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = clampToBounds(convert(event.locationInWindow, from: nil))
        cursorPoint = point

        if toolbarModel.isSelectingArea {
            selectionStartPoint = point
            captureRect = NSRect(origin: point, size: .zero)
            toolbarModel.hasSelection = true
        } else {
            currentStroke = Stroke(points: [point], width: CGFloat(toolbarModel.brushSize))
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = clampToBounds(convert(event.locationInWindow, from: nil))
        cursorPoint = point

        if toolbarModel.isSelectingArea {
            if let selectionStartPoint {
                captureRect = normalizedRect(from: selectionStartPoint, to: point)
                toolbarModel.hasSelection = !(captureRect?.isEmpty ?? true)
            }
        } else {
            currentStroke?.points.append(point)
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = clampToBounds(convert(event.locationInWindow, from: nil))
        cursorPoint = point

        if toolbarModel.isSelectingArea {
            if let selectionStartPoint {
                let rect = normalizedRect(from: selectionStartPoint, to: point)
                captureRect = rect.width < 2 || rect.height < 2 ? nil : rect
                toolbarModel.hasSelection = captureRect != nil
            }
            selectionStartPoint = nil
            toolbarModel.isSelectingArea = false
        } else if var currentStroke {
            currentStroke.points.append(point)
            strokes.append(currentStroke)
            self.currentStroke = nil
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.04).setFill()
        dirtyRect.fill()

        if !hidesCaptureDecorations {
            drawSelectionOverlay()
        }
        drawStrokes()
        if !hidesCaptureDecorations {
            drawCursor()
        }
    }

    func drawingImage(scale: CGFloat) -> NSImage {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(Int(bounds.width * scale), 1),
            pixelsHigh: max(Int(bounds.height * scale), 1),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let bitmap,
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return NSImage(size: bounds.size)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: scale, y: scale)
        drawStrokes()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    func hideCaptureDecorations() {
        hidesCaptureDecorations = true
        needsDisplay = true
        displayIfNeeded()
    }

    private func undoLastStroke() {
        guard !strokes.isEmpty else { return }
        _ = strokes.popLast()
        needsDisplay = true
    }

    private func drawSelectionOverlay() {
        guard let captureRect, !captureRect.isEmpty else { return }

        let selectionPath = NSBezierPath(rect: bounds)
        selectionPath.append(NSBezierPath(rect: captureRect))
        selectionPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.22).setFill()
        selectionPath.fill()

        NSColor.white.withAlphaComponent(0.85).setStroke()
        let outline = NSBezierPath(rect: captureRect)
        outline.lineWidth = 2
        outline.setLineDash([8, 6], count: 2, phase: 0)
        outline.stroke()
    }

    private func drawStrokes() {
        for stroke in strokes {
            draw(stroke: stroke)
        }

        if let currentStroke {
            draw(stroke: currentStroke)
        }
    }

    private func draw(stroke: Stroke) {
        strokeColor.setStroke()

        guard stroke.points.count >= 2 else {
            if let point = stroke.points.first {
                let dotRect = NSRect(
                    x: point.x - stroke.width / 2,
                    y: point.y - stroke.width / 2,
                    width: stroke.width,
                    height: stroke.width
                )
                strokeColor.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return
        }

        let path = NSBezierPath()
        path.lineWidth = stroke.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: stroke.points[0])

        for point in stroke.points.dropFirst() {
            path.line(to: point)
        }

        path.stroke()
    }

    private func drawCursor() {
        guard let cursorPoint else { return }

        let radius = CGFloat(toolbarModel.brushSize)
        let cursorRect = NSRect(
            x: cursorPoint.x - radius,
            y: cursorPoint.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        if toolbarModel.isSelectingArea {
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let crosshair = NSBezierPath()
            crosshair.move(to: NSPoint(x: cursorPoint.x - 10, y: cursorPoint.y))
            crosshair.line(to: NSPoint(x: cursorPoint.x + 10, y: cursorPoint.y))
            crosshair.move(to: NSPoint(x: cursorPoint.x, y: cursorPoint.y - 10))
            crosshair.line(to: NSPoint(x: cursorPoint.x, y: cursorPoint.y + 10))
            crosshair.lineWidth = 2
            crosshair.stroke()
            return
        }

        cursorFillColor.setFill()
        NSBezierPath(ovalIn: cursorRect).fill()

        NSColor.white.withAlphaComponent(0.9).setStroke()
        let outer = NSBezierPath(ovalIn: cursorRect)
        outer.lineWidth = 2
        outer.stroke()
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func clampToBounds(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
