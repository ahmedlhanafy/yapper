import XCTest
@testable import Yapper

final class YapperTests: XCTestCase {
    func testModeCreation() {
        let mode = Mode.voiceToText
        XCTAssertEqual(mode.name, "Voice to Text")
        XCTAssertEqual(mode.key, "voice-to-text")
        XCTAssertTrue(mode.isBuiltIn)
        XCTAssertFalse(mode.aiEnabled)
    }

    func testSessionMatches() {
        let session = Session(
            audioFilePath: "/tmp/test.wav",
            duration: 5.0,
            rawTranscript: "Hello world, this is a test",
            mode: Mode.voiceToText
        )

        XCTAssertTrue(session.matches(searchText: "hello"))
        XCTAssertTrue(session.matches(searchText: "test"))
        XCTAssertFalse(session.matches(searchText: "goodbye"))
    }

    func testHotkeyDisplayString() {
        let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
        XCTAssertEqual(hotkey.displayString, "⌘⇧Space")
    }

    func testSettingsDefaults() {
        let settings = Settings()
        XCTAssertFalse(settings.startAtLogin)
        XCTAssertTrue(settings.recordOnMenubarClick)
        XCTAssertTrue(settings.enableNormalization)
        XCTAssertEqual(settings.modes.count, 6) // 6 built-in modes
    }

    func testAIProviderDefaults() {
        XCTAssertEqual(AIProvider.openai.defaultModel, "gpt-4")
        XCTAssertEqual(AIProvider.anthropic.defaultModel, "claude-3-5-sonnet-20241022")
    }
}
