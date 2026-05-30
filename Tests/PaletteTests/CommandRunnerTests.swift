import Testing
import Foundation
@testable import Palette

@Test func runnerExecutesSimpleCommand() async throws {
    let runner = CommandRunner()
    let result = try await runner.run(script: "echo hello")
    #expect(result.output == "hello")
    #expect(result.exitCode == 0)
}

@Test func runnerCapturesStderr() async throws {
    let runner = CommandRunner()
    let result = try await runner.run(script: "echo error >&2")
    #expect(result.error == "error")
    #expect(result.exitCode == 0)
}

@Test func runnerReportsNonZeroExit() async throws {
    let runner = CommandRunner()
    let result = try await runner.run(script: "exit 42")
    #expect(result.exitCode == 42)
}

@Test func runnerExecutesCommand() async throws {
    let runner = CommandRunner()
    let cmd = Command(name: "Test", description: "test", section: "Shell", script: "echo palette", icon: nil, shortcut: nil)
    let result = try await runner.run(cmd)
    #expect(result.output == "palette")
}
