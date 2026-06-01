import Testing
import AppKit
@testable import Palette

@Test func cropGeometryFlipsYAxisForCGImageCropping() {
    let cropRect = NSRect(x: 100, y: 200, width: 300, height: 150)
    let pixelRect = ScreenBrushCropGeometry.pixelCropRect(
        imageSize: NSSize(width: 1000, height: 800),
        cropRect: cropRect,
        scale: 2
    )

    #expect(pixelRect.origin.x == 200)
    #expect(pixelRect.origin.y == 900)
    #expect(pixelRect.width == 600)
    #expect(pixelRect.height == 300)
}

@Test func bundledPNGOptimizerExistsForCurrentArchitecture() {
    let executableURL = PNGOptimizer.bundledExecutableURL()

    #expect(executableURL != nil)
    if let executableURL {
        #expect(FileManager.default.isExecutableFile(atPath: executableURL.path))
    }
}

@Test func defaultCaptureRectUsesScreenContainingMouse() {
    let leftScreen = ScreenBrushScreenDescriptor(
        displayID: 1,
        frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: NSRect(x: 0, y: 25, width: 1440, height: 853),
        backingScaleFactor: 2
    )
    let rightScreen = ScreenBrushScreenDescriptor(
        displayID: 2,
        frame: NSRect(x: 1440, y: 0, width: 1728, height: 1117),
        visibleFrame: NSRect(x: 1440, y: 25, width: 1728, height: 1070),
        backingScaleFactor: 2
    )

    let focusedScreen = ScreenBrushTargetGeometry.focusedScreen(
        at: NSPoint(x: 1800, y: 400),
        screens: [leftScreen, rightScreen],
        fallback: leftScreen
    )

    #expect(focusedScreen == rightScreen)

    let captureRect = ScreenBrushTargetGeometry.defaultCaptureRect(
        focusedScreenFrame: rightScreen.frame,
        unionFrame: rightScreen.frame
    )

    #expect(captureRect == NSRect(x: 0, y: 0, width: 1728, height: 1117))
}

@Test func toolbarAndPreviewStayOnFocusedScreen() {
    let unionFrame = NSRect(x: 0, y: 0, width: 3168, height: 1117)
    let focusedVisibleFrame = NSRect(x: 1440, y: 25, width: 1728, height: 1070)

    let toolbarFrame = ScreenBrushTargetGeometry.toolbarFrame(
        toolbarSize: NSSize(width: 520, height: 54),
        focusedVisibleFrame: focusedVisibleFrame,
        unionFrame: unionFrame
    )
    let previewOrigin = ScreenBrushTargetGeometry.previewOrigin(
        panelSize: NSSize(width: 280, height: 118),
        focusedVisibleFrame: focusedVisibleFrame
    )

    #expect(toolbarFrame.minX >= focusedVisibleFrame.minX - unionFrame.minX)
    #expect(toolbarFrame.maxX <= focusedVisibleFrame.maxX - unionFrame.minX)
    #expect(toolbarFrame.maxY <= focusedVisibleFrame.maxY - unionFrame.minY)
    #expect(previewOrigin.x == 2868)
    #expect(previewOrigin.y == 45)
}
