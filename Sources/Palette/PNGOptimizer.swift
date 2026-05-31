import Foundation

struct PNGOptimizationResult: Equatable {
    let savedBytes: Int64
    let savedPercent: Double
}

enum PNGOptimizer {
    private static let arguments = ["-o", "4", "--strip", "safe", "--alpha", "--quiet"]

    @discardableResult
    static func optimizeIfAvailable(fileURL: URL) -> PNGOptimizationResult? {
        guard let executableURL = bundledExecutableURL() else {
            return nil
        }

        let originalSize = fileSize(at: fileURL)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments + [fileURL.path]

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let originalSize,
                  let optimizedSize = fileSize(at: fileURL) else {
                return nil
            }

            let savedBytes = originalSize - optimizedSize
            guard savedBytes > 0 else {
                return nil
            }

            let savedPercent = Double(savedBytes) / Double(originalSize) * 100
            print("Optimized PNG: \(savedBytes) bytes saved (\(String(format: "%.1f", savedPercent))%)")
            return PNGOptimizationResult(savedBytes: savedBytes, savedPercent: savedPercent)
        } catch {
            return nil
        }
    }

    static func bundledExecutableURL() -> URL? {
        let fileName: String
        switch ProcessInfo.processInfo.machineHardwareName {
        case "arm64":
            fileName = "oxipng-aarch64-apple-darwin"
        case "x86_64":
            fileName = "oxipng-x86_64-apple-darwin"
        default:
            return nil
        }

        return Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "Tools")
    }

    private static func fileSize(at fileURL: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return nil
        }

        return fileSize.int64Value
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)

        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)

        return String(decoding: machine.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
