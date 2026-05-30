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

@Test func registryReloadsWhenJSONChanges() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let original = """
    [{"name":"One","description":"First","script":"date","icon":null,"shortcut":null}]
    """.data(using: .utf8)!
    try original.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()

    let updated = """
    [{"name":"Two","description":"Second","script":"whoami","icon":null,"shortcut":null}]
    """.data(using: .utf8)!
    try updated.write(to: file)

    try await registry.reloadIfChanged()

    #expect(await registry.commands.count == 1)
    #expect(await registry.commands[0].name == "Two")

    try? FileManager.default.removeItem(at: tmp)
}

@Test func registryMovesCommandAndPersistsOrder() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let json = """
    [
      {"name":"One","description":"First","script":"date","icon":null,"shortcut":null},
      {"name":"Two","description":"Second","script":"whoami","icon":null,"shortcut":null},
      {"name":"Three","description":"Third","script":"pwd","icon":null,"shortcut":null}
    ]
    """.data(using: .utf8)!
    try json.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()
    try await registry.moveCommand(id: "Three", before: "One")

    #expect(await registry.commands.map(\.name) == ["Three", "One", "Two"])

    let persisted = try JSONDecoder().decode([Command].self, from: Data(contentsOf: file))
    #expect(persisted.map(\.name) == ["Three", "One", "Two"])

    try? FileManager.default.removeItem(at: tmp)
}
