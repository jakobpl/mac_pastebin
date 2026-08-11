import AppKit
import XCTest
@testable import writer

@MainActor
final class RichTextEditingTests: XCTestCase {
    func testFormattingPreviewCancelsWithoutSavingAndCommitCreatesOneChange() throws {
        let context = RichTextEditorContext()
        var savedChanges = 0
        let editor = RichTextEditor(
            noteID: "note",
            plainText: "Preview this text",
            richContent: nil,
            context: context,
            onChange: { _, _ in savedChanges += 1 },
            onError: { _ in },
            onFocus: {}
        )
        let coordinator = editor.makeCoordinator()
        let textView = WriterTextView()
        coordinator.textView = textView
        coordinator.load(noteID: "note", plainText: "Preview this text", richContent: nil)
        textView.setSelectedRange(NSRange(location: 0, length: 7))

        coordinator.previewFontSize(42)
        XCTAssertEqual(fontSize(at: 0, in: textView), 42, accuracy: 0.01)
        XCTAssertEqual(savedChanges, 0)

        coordinator.cancelFormattingPreview()
        XCTAssertEqual(fontSize(at: 0, in: textView), 19, accuracy: 0.01)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 7))
        XCTAssertEqual(savedChanges, 0)

        coordinator.previewFontSize(32)
        coordinator.commitFormattingPreview()
        XCTAssertEqual(fontSize(at: 0, in: textView), 32, accuracy: 0.01)
        XCTAssertEqual(savedChanges, 1)
    }

    func testDocumentKeyboardShortcutsRouteToFormattingCommands() throws {
        let textView = WriterTextView()
        var received: [EditorFormattingCommand] = []
        textView.onFormattingCommand = { received.append($0) }

        XCTAssertTrue(textView.performKeyEquivalent(with: try keyEvent("b", modifiers: .command, keyCode: 11)))
        XCTAssertTrue(textView.performKeyEquivalent(with: try keyEvent("1", modifiers: [.command, .option], keyCode: 18)))
        XCTAssertTrue(textView.performKeyEquivalent(with: try keyEvent("x", modifiers: [.command, .shift], keyCode: 7)))

        XCTAssertEqual(received.count, 3)
        if case .toggleBold = received[0] {} else { XCTFail("Expected bold command") }
        if case .heading(1) = received[1] {} else { XCTFail("Expected Heading 1 command") }
        if case .toggleStrikethrough = received[2] {} else { XCTFail("Expected strikethrough command") }
    }

    func testDocumentCommandsApplyCharacterParagraphAndListFormatting() throws {
        let context = RichTextEditorContext()
        let editor = RichTextEditor(
            noteID: "note",
            plainText: "First paragraph\nSecond paragraph",
            richContent: nil,
            context: context,
            onChange: { _, _ in },
            onError: { _ in },
            onFocus: {}
        )
        let coordinator = editor.makeCoordinator()
        let textView = WriterTextView()
        coordinator.textView = textView
        coordinator.load(noteID: "note", plainText: "First paragraph\nSecond paragraph", richContent: nil)
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        coordinator.performEditorCommand(.toggleBold)
        let boldFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))

        coordinator.performEditorCommand(.toggleUnderline)
        XCTAssertEqual(textView.textStorage?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)

        coordinator.performEditorCommand(.heading(1))
        XCTAssertEqual(fontSize(at: 0, in: textView), 32, accuracy: 0.01)

        coordinator.performEditorCommand(.alignCenter)
        let centered = try XCTUnwrap(textView.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(centered.alignment, .center)

        coordinator.performEditorCommand(.bulletedList)
        let listed = try XCTUnwrap(textView.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(listed.textLists.count, 1)
        XCTAssertEqual(listed.textLists.first?.markerFormat, .disc)
    }

    private func fontSize(at location: Int, in textView: NSTextView) -> CGFloat {
        (textView.textStorage?.attribute(.font, at: location, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
    }

    private func keyEvent(
        _ character: String,
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16
    ) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: character,
                charactersIgnoringModifiers: character,
                isARepeat: false,
                keyCode: keyCode
            )
        )
    }
}
