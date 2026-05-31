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
    [{"name":"Custom","description":"Custom cmd","section":"Yabai","script":"whoami","icon":null,"shortcut":null,"tileRow":1,"tileColumn":2}]
    """.data(using: .utf8)!
    try json.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()

    #expect(await registry.commands.count == 1)
    #expect(await registry.commands[0].name == "Custom")
    #expect(await registry.commands[0].section == "Yabai")
    #expect(await registry.commands[0].tileRow == 1)
    #expect(await registry.commands[0].tileColumn == 2)

    try? FileManager.default.removeItem(at: tmp)
}

@Test func registryReloadsWhenJSONChanges() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let original = """
    [{"name":"One","description":"First","section":null,"script":"date","icon":null,"shortcut":null,"tileRow":0,"tileColumn":0}]
    """.data(using: .utf8)!
    try original.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()

    let updated = """
    [{"name":"Two","description":"Second","section":"Ops","script":"whoami","icon":null,"shortcut":null,"tileRow":0,"tileColumn":1}]
    """.data(using: .utf8)!
    try updated.write(to: file)

    try await registry.reloadIfChanged()

    #expect(await registry.commands.count == 1)
    #expect(await registry.commands[0].name == "Two")
    #expect(await registry.commands[0].section == "Ops")
    #expect(await registry.commands[0].tileColumn == 1)

    try? FileManager.default.removeItem(at: tmp)
}

@Test func registryPlacesCommandAndPersistsGrid() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let json = """
    [
      {"name":"One","description":"First","section":"Alpha","script":"date","icon":null,"shortcut":null,"tileRow":0,"tileColumn":0},
      {"name":"Two","description":"Second","section":"Alpha","script":"whoami","icon":null,"shortcut":null,"tileRow":0,"tileColumn":1},
      {"name":"Three","description":"Third","section":"Beta","script":"pwd","icon":null,"shortcut":null,"tileRow":0,"tileColumn":0}
    ]
    """.data(using: .utf8)!
    try json.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()
    try await registry.placeCommand(id: "Three", in: "Alpha", row: 0, column: 1)

    let commands = await registry.commands
    let one = try #require(commands.first(where: { $0.name == "One" }))
    let two = try #require(commands.first(where: { $0.name == "Two" }))
    let three = try #require(commands.first(where: { $0.name == "Three" }))

    #expect(one.section == "Alpha")
    #expect(one.tileRow == 0)
    #expect(one.tileColumn == 0)
    #expect(two.section == "Beta")
    #expect(two.tileRow == 0)
    #expect(two.tileColumn == 0)
    #expect(three.section == "Alpha")
    #expect(three.tileRow == 0)
    #expect(three.tileColumn == 1)

    let persisted = try JSONDecoder().decode([Command].self, from: Data(contentsOf: file))
    let persistedTwo = try #require(persisted.first(where: { $0.name == "Two" }))
    let persistedThree = try #require(persisted.first(where: { $0.name == "Three" }))
    #expect(persistedTwo.section == "Beta")
    #expect(persistedThree.tileColumn == 1)

    try? FileManager.default.removeItem(at: tmp)
}

@Test func registryNormalizesMissingAndDuplicateGridPositions() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let json = """
    [
      {"name":"One","description":"First","section":"Alpha","script":"date","icon":null,"shortcut":null,"tileRow":0,"tileColumn":0},
      {"name":"Two","description":"Second","section":"Alpha","script":"whoami","icon":null,"shortcut":null,"tileRow":0,"tileColumn":0},
      {"name":"Three","description":"Third","section":"Alpha","script":"pwd","icon":null,"shortcut":null}
    ]
    """.data(using: .utf8)!
    try json.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()

    let commands = await registry.commands
    #expect(commands.map(\.tileRow) == [0, 0, 0])
    #expect(commands.map(\.tileColumn) == [0, 1, 2])

    try? FileManager.default.removeItem(at: tmp)
}
