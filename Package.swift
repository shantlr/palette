// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Palette",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Palette",
            path: "Sources/Palette",
            exclude: ["Info.plist"],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Palette/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "PaletteTests",
            dependencies: ["Palette"],
            path: "Tests/PaletteTests"
        ),
    ]
)
