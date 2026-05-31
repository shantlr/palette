import Testing
import Foundation
@testable import Palette

@Test func commandDecodesFromJSON() throws {
    let json = """
    {
        "name": "Test",
        "description": "A test command",
        "section": "Yabai",
        "script": "echo hello",
        "icon": "star",
        "shortcut": null,
        "tileRow": 2,
        "tileColumn": 4
    }
    """.data(using: .utf8)!

    let command = try JSONDecoder().decode(Command.self, from: json)
    #expect(command.name == "Test")
    #expect(command.script == "echo hello")
    #expect(command.icon == "star")
    #expect(command.section == "Yabai")
    #expect(command.tileRow == 2)
    #expect(command.tileColumn == 4)
    #expect(command.id == "Test")
}

@Test func commandEncodesRoundTrip() throws {
    let command = Command(name: "Foo", description: "Bar", section: "Shell", script: "ls", icon: nil, shortcut: "cmd+f", tileRow: 1, tileColumn: 3)
    let data = try JSONEncoder().encode(command)
    let decoded = try JSONDecoder().decode(Command.self, from: data)
    #expect(decoded.name == command.name)
    #expect(decoded.section == "Shell")
    #expect(decoded.shortcut == "cmd+f")
    #expect(decoded.tileRow == 1)
    #expect(decoded.tileColumn == 3)
}
