import Testing
import Foundation
@testable import Palette

@Test func registryCreatesDefaultsWhenNoFile() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("commands.json")

    let registry = await CommandRegistry(configURL: tmp)
    try await registry.load()

    #expect(await registry.commands.count == 3)
    #expect(FileManager.default.fileExists(atPath: tmp.path))

    try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent())
}

@Test func registryLoadsCustomCommands() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let json = """
    [{"name":"Custom","description":"Custom cmd","script":"whoami","icon":null,"shortcut":null}]
    """.data(using: .utf8)!
    try json.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()

    #expect(await registry.commands.count == 1)
    #expect(await registry.commands[0].name == "Custom")

    try? FileManager.default.removeItem(at: tmp)
}
