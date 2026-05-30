import Testing
import Foundation
@testable import Palette

@Test func commandDecodesFromJSON() throws {
    let json = """
    {
        "name": "Test",
        "description": "A test command",
        "script": "echo hello",
        "icon": "star",
        "shortcut": null
    }
    """.data(using: .utf8)!

    let command = try JSONDecoder().decode(Command.self, from: json)
    #expect(command.name == "Test")
    #expect(command.script == "echo hello")
    #expect(command.icon == "star")
    #expect(command.id == "Test")
}

@Test func commandEncodesRoundTrip() throws {
    let command = Command(name: "Foo", description: "Bar", script: "ls", icon: nil, shortcut: "cmd+f")
    let data = try JSONEncoder().encode(command)
    let decoded = try JSONDecoder().decode(Command.self, from: data)
    #expect(decoded.name == command.name)
    #expect(decoded.shortcut == "cmd+f")
}
