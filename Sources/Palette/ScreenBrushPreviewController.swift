import AppKit
import SwiftUI

@MainActor
final class ScreenBrushPreviewController: NSObject {
    private static let autoDismissDelay: TimeInterval = 20

    private var previewPanel: ScreenshotPreviewPanel?
    private var dismissWorkItem: DispatchWorkItem?
    var lastOptimizationResult: PNGOptimizationResult?

    func show(image: NSImage, fileURL: URL?, focusedVisibleFrame: NSRect) {
        let panel: ScreenshotPreviewPanel
        if let previewPanel {
            panel = previewPanel
        } else {
            let newPanel = ScreenshotPreviewPanel(
                onOpen: { [weak self] in
                    self?.openEditor()
                },
                onDismiss: { [weak self] in
                    self?.dismissPreview()
                }
            )
            previewPanel = newPanel
            panel = newPanel
        }

        panel.update(image: image, fileURL: fileURL, optimizationResult: lastOptimizationResult)
        panel.positionInBottomRight(focusedVisibleFrame: focusedVisibleFrame)
        panel.orderFrontRegardless()
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dismissPreview()
        }

        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoDismissDelay, execute: workItem)
    }

    private func openEditor() {
        dismissWorkItem?.cancel()
        guard let previewPanel else { return }

        openInPreview(image: previewPanel.image, fileURL: previewPanel.fileURL)
        dismissPreview()
    }

    private func dismissPreview() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        previewPanel?.close()
        previewPanel = nil
    }

    private func openInPreview(image: NSImage, fileURL: URL?) {
        let targetURL = fileURL ?? writeTemporaryImage(image)
        guard let targetURL else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open([targetURL], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"), configuration: NSWorkspace.OpenConfiguration())
    }

    private func writeTemporaryImage(_ image: NSImage) -> URL? {
        guard let pngData = encodePNG(image) else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("palette-preview-")
            .appendingPathExtension("png")

        let uniqueURL = tempURL.deletingPathExtension().appendingPathExtension("\(UUID().uuidString).png")

        do {
            try pngData.write(to: uniqueURL)
            _ = PNGOptimizer.optimizeIfAvailable(fileURL: uniqueURL)
            return uniqueURL
        } catch {
            return nil
        }
    }
}

@MainActor
private final class ScreenshotPreviewPanel: NSPanel {
    private static let panelSize = NSSize(width: 280, height: 118)

    private let contentModel = ScreenshotPreviewContentModel()
    private let onOpen: () -> Void
    private let onDismiss: () -> Void

    var image: NSImage {
        contentModel.image
    }

    var fileURL: URL? {
        contentModel.fileURL
    }

    init(onOpen: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onDismiss = onDismiss

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false

        let hostingView = NSHostingView(
            rootView: ScreenshotPreviewCardView(model: contentModel, onOpen: onOpen, onDismiss: onDismiss)
        )
        hostingView.frame = NSRect(origin: .zero, size: Self.panelSize)
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func update(image: NSImage, fileURL: URL?, optimizationResult: PNGOptimizationResult?) {
        contentModel.image = image
        contentModel.fileURL = fileURL
        contentModel.optimizationResult = optimizationResult
    }

    func positionInBottomRight(focusedVisibleFrame: NSRect) {
        setFrameOrigin(
            ScreenBrushTargetGeometry.previewOrigin(
                panelSize: Self.panelSize,
                focusedVisibleFrame: focusedVisibleFrame
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onOpen()
    }
}

@MainActor
private final class ScreenshotPreviewContentModel: ObservableObject {
    @Published var image = NSImage(size: NSSize(width: 1, height: 1))
    @Published var fileURL: URL?
    @Published var optimizationResult: PNGOptimizationResult?
}

private struct ScreenshotPreviewCardView: View {
    @ObservedObject var model: ScreenshotPreviewContentModel
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(nsImage: model.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.white.opacity(0.22))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screenshot Saved")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(model.fileURL?.lastPathComponent ?? "Open in editor")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text("Click to open editor")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        if let optimizationResult = model.optimizationResult {
                            Text("PNG optimized: \(ByteCountFormatter.string(fromByteCount: optimizationResult.savedBytes, countStyle: .file)) saved (\(String(format: "%.1f", optimizationResult.savedPercent))%)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white.opacity(0.16))
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }
}
