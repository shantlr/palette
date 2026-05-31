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
