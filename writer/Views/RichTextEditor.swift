import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
protocol RichTextEditorCommandHandling: AnyObject {
    func applyFontFamily(_ family: String)
    func previewFontFamily(_ family: String)
    func applyFontSize(_ size: Double)
    func previewFontSize(_ size: Double)
    func toggleBold()
    func toggleItalic()
    func applyTextColor(_ color: NSColor)
    func previewTextColor(_ color: NSColor)
    func cancelFormattingPreview()
    func commitFormattingPreview()
    func performEditorCommand(_ command: EditorFormattingCommand)
    func insertImage()
    func applySelectedImageWidth(_ fraction: Double)
    func focusEditor()
    func clearEditor()
}

enum EditorFormattingCommand {
    case toggleBold
    case toggleItalic
    case toggleUnderline
    case toggleStrikethrough
    case heading(Int)
    case copyFormatting
    case pasteFormatting
    case clearFormatting
    case increaseFontSize
    case decreaseFontSize
    case subscriptText
    case superscriptText
    case alignLeft
    case alignCenter
    case alignRight
    case justify
    case bulletedList
    case numberedList
    case indent
    case outdent
}

@MainActor
final class RichTextEditorContext: ObservableObject {
    @Published private(set) var fontFamily: String? = NSFont.systemFont(ofSize: 19).familyName
    @Published private(set) var fontSize: Double? = 19
    @Published private(set) var isBold: Bool?
    @Published private(set) var isItalic: Bool?
    @Published private(set) var textColor = NSColor.writerPaperInk
    @Published private(set) var selectedImageWidth: Double?

    weak var commandHandler: RichTextEditorCommandHandling?

    var hasSelectedImage: Bool {
        selectedImageWidth != nil
    }

    func applyFontFamily(_ family: String) {
        commandHandler?.applyFontFamily(family)
    }

    func previewFontFamily(_ family: String) {
        commandHandler?.previewFontFamily(family)
    }

    func applyFontSize(_ size: Double) {
        commandHandler?.applyFontSize(min(max(size, 6), 144))
    }

    func previewFontSize(_ size: Double) {
        commandHandler?.previewFontSize(min(max(size, 6), 144))
    }

    func toggleBold() {
        commandHandler?.toggleBold()
    }

    func toggleItalic() {
        commandHandler?.toggleItalic()
    }

    func applyTextColor(_ color: NSColor) {
        commandHandler?.applyTextColor(color)
    }

    func previewTextColor(_ color: NSColor) {
        commandHandler?.previewTextColor(color)
    }

    func cancelFormattingPreview() {
        commandHandler?.cancelFormattingPreview()
    }

    func commitFormattingPreview() {
        commandHandler?.commitFormattingPreview()
    }

    func insertImage() {
        commandHandler?.insertImage()
    }

    func applySelectedImageWidth(_ percentage: Double) {
        commandHandler?.applySelectedImageWidth(min(max(percentage / 100, 0.10), 1))
    }

    func focusEditor() {
        commandHandler?.focusEditor()
    }

    func clear() {
        commandHandler?.clearEditor()
        commandHandler = nil
    }

    fileprivate func update(
        fontFamily: String?,
        fontSize: Double?,
        isBold: Bool?,
        isItalic: Bool?,
        textColor: NSColor,
        selectedImageWidth: Double?
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.textColor = textColor
        self.selectedImageWidth = selectedImageWidth.map { $0 * 100 }
    }
}

struct FontFamilyComboBox: NSViewRepresentable {
    @Binding var family: String
    let onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.completes = true
        comboBox.isEditable = true
        comboBox.font = .systemFont(ofSize: 13)
        comboBox.addItems(withObjectValues: NSFontManager.shared.availableFontFamilies.sorted())
        comboBox.stringValue = family
        comboBox.delegate = context.coordinator
        comboBox.setAccessibilityLabel("Font family")
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.parent = self
        if comboBox.currentEditor() == nil, comboBox.stringValue != family {
            comboBox.stringValue = family
        }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: FontFamilyComboBox

        init(parent: FontFamilyComboBox) {
            self.parent = parent
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            commit(notification)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            commit(obj)
        }

        private func commit(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else {
                return
            }

            let value = comboBox.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard NSFontManager.shared.availableFontFamilies.contains(value) else {
                comboBox.stringValue = parent.family
                return
            }

            parent.family = value
            parent.onCommit(value)
        }
    }
}

struct RichTextEditor: NSViewRepresentable {
    let noteID: String?
    let plainText: String
    let richContent: VaultRichContent?
    let context: RichTextEditorContext
    let onChange: (String, VaultRichContent) -> Void
    let onError: (String) -> Void
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = WriterTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 22, height: 22)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.drawsBackground = false
        textView.textColor = .writerPaperInk
        textView.insertionPointColor = .writerPaperInk
        textView.font = .systemFont(ofSize: 19)
        textView.typingAttributes = Coordinator.defaultAttributes
        textView.setAccessibilityLabel("Note editor")

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.configureImageInteractions()
        self.context.commandHandler = context.coordinator
        context.coordinator.load(noteID: noteID, plainText: plainText, richContent: richContent)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        self.context.commandHandler = context.coordinator

        if context.coordinator.loadedNoteID != noteID {
            context.coordinator.load(noteID: noteID, plainText: plainText, richContent: richContent)
        }

        DispatchQueue.main.async {
            context.coordinator.updateAttachmentBounds()
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.clearEditor()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, RichTextEditorCommandHandling {
        static let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 19),
            .foregroundColor: NSColor.writerPaperInk
        ]

        var parent: RichTextEditor
        weak var textView: WriterTextView?
        var loadedNoteID: String?
        private var imageDisplayWidths: [String: Double] = [:]
        private var attachmentIDsByObject: [ObjectIdentifier: String] = [:]
        private var imageSourcesByID: [String: VaultImageSource] = [:]
        private var isLoading = false
        private var formattingPreview: FormattingPreview?
        private var copiedFormatting: [NSAttributedString.Key: Any]?

        private struct FormattingPreview {
            let attributedString: NSAttributedString
            let typingAttributes: [NSAttributedString.Key: Any]
            let selection: NSRange
            let imageDisplayWidths: [String: Double]
            let actionName: String
        }

        init(parent: RichTextEditor) {
            self.parent = parent
        }

        func configureImageInteractions() {
            guard let textView else { return }
            textView.onSelectImage = { [weak self] location in
                self?.selectImage(at: location)
            }
            textView.onDeleteImage = { [weak self] location in
                self?.deleteImage(at: location)
            }
            textView.onBeginImageResize = { [weak self] location in
                self?.beginImageResize(at: location)
            }
            textView.onResizeImage = { [weak self] location, fraction in
                self?.resizeImage(at: location, to: fraction)
            }
            textView.onViewportWidthChange = { [weak self] in
                self?.updateAttachmentBounds()
            }
            textView.onFormattingCommand = { [weak self] command in
                self?.performEditorCommand(command)
            }
        }

        func load(noteID: String?, plainText: String, richContent: VaultRichContent?) {
            guard let textView else {
                return
            }

            isLoading = true
            loadedNoteID = noteID
            imageDisplayWidths = richContent?.imageDisplayWidths ?? [:]
            attachmentIDsByObject.removeAll(keepingCapacity: true)
            imageSourcesByID = Dictionary(
                uniqueKeysWithValues: (richContent?.imageSources ?? []).map { ($0.id, $0) }
            )

            let attributedString: NSAttributedString
            if let data = richContent?.rtfdData,
               let decoded = NSAttributedString(rtfd: data, documentAttributes: nil) {
                attributedString = decoded
            } else {
                attributedString = NSAttributedString(string: plainText, attributes: Self.defaultAttributes)
            }

            textView.textStorage?.setAttributedString(attributedString)
            rebuildAttachmentsFromOriginalSources(richContent?.imageAttachmentIDs ?? [])
            textView.typingAttributes = Self.defaultAttributes
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            assignAttachmentIdentifiers(richContent?.imageAttachmentIDs ?? [])
            updateAttachmentBounds()
            updateSelectionState()
            isLoading = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isLoading else {
                return
            }

            emitChange()
            updateSelectionState()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateSelectionState()
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocus()
            updateSelectionState()
        }

        func applyFontFamily(_ family: String) {
            transformFonts { font in
                NSFontManager.shared.convert(font, toFamily: family)
            }
        }

        func previewFontFamily(_ family: String) {
            previewFormatting(actionName: "Change Font") { [weak self] in
                self?.transformFontsWithoutCommit { font in
                    NSFontManager.shared.convert(font, toFamily: family)
                }
            }
        }

        func applyFontSize(_ size: Double) {
            let clampedSize = CGFloat(min(max(size, 6), 144))
            transformFonts { font in
                NSFontManager.shared.convert(font, toSize: clampedSize)
            }
        }

        func previewFontSize(_ size: Double) {
            let clampedSize = CGFloat(min(max(size, 6), 144))
            previewFormatting(actionName: "Change Font Size") { [weak self] in
                self?.transformFontsWithoutCommit { font in
                    NSFontManager.shared.convert(font, toSize: clampedSize)
                }
            }
        }

        func toggleBold() {
            let shouldEnable = parent.context.isBold != true
            transformFonts { font in
                NSFontManager.shared.convert(
                    font,
                    toHaveTrait: shouldEnable ? .boldFontMask : .unboldFontMask
                )
            }
        }

        func toggleItalic() {
            let shouldEnable = parent.context.isItalic != true
            transformFonts { font in
                NSFontManager.shared.convert(
                    font,
                    toHaveTrait: shouldEnable ? .italicFontMask : .unitalicFontMask
                )
            }
        }

        func applyTextColor(_ color: NSColor) {
            applyAttribute(.foregroundColor, value: color)
        }

        func previewTextColor(_ color: NSColor) {
            previewFormatting(actionName: "Change Text Color") { [weak self] in
                self?.applyAttributeWithoutCommit(.foregroundColor, value: color)
            }
        }

        func cancelFormattingPreview() {
            guard let preview = formattingPreview else { return }
            restorePreview(preview)
            formattingPreview = nil
            updateSelectionState()
        }

        func commitFormattingPreview() {
            guard let preview = formattingPreview, let textView else { return }
            formattingPreview = nil
            registerUndo(
                attributedString: preview.attributedString,
                imageDisplayWidths: preview.imageDisplayWidths,
                selection: preview.selection,
                actionName: preview.actionName
            )
            textView.undoManager?.setActionName(preview.actionName)
            emitChange()
            updateSelectionState()
        }

        func performEditorCommand(_ command: EditorFormattingCommand) {
            switch command {
            case .toggleBold:
                toggleBold()
            case .toggleItalic:
                toggleItalic()
            case .toggleUnderline:
                toggleIntegerAttribute(.underlineStyle, actionName: "Underline")
            case .toggleStrikethrough:
                toggleIntegerAttribute(.strikethroughStyle, actionName: "Strikethrough")
            case .heading(let level):
                applyHeading(level)
            case .copyFormatting:
                copySelectedFormatting()
            case .pasteFormatting:
                pasteCopiedFormatting()
            case .clearFormatting:
                clearSelectedFormatting()
            case .increaseFontSize:
                adjustFontSize(by: 1)
            case .decreaseFontSize:
                adjustFontSize(by: -1)
            case .subscriptText:
                toggleScript(-1)
            case .superscriptText:
                toggleScript(1)
            case .alignLeft:
                applyAlignment(.left)
            case .alignCenter:
                applyAlignment(.center)
            case .alignRight:
                applyAlignment(.right)
            case .justify:
                applyAlignment(.justified)
            case .bulletedList:
                applyList(markerFormat: .disc)
            case .numberedList:
                applyList(markerFormat: .decimal)
            case .indent:
                adjustIndent(by: 24)
            case .outdent:
                adjustIndent(by: -24)
            }
        }

        private func toggleIntegerAttribute(_ key: NSAttributedString.Key, actionName: String) {
            guard let textView, let storage = textView.textStorage else { return }
            let range = effectiveFormattingRange(in: textView, storage: storage)
            let current = range.length > 0
                ? (storage.attribute(key, at: range.location, effectiveRange: nil) as? Int ?? 0)
                : (textView.typingAttributes[key] as? Int ?? 0)
            performMutation(actionName: actionName) {
                self.applyAttributeWithoutCommit(key, value: current == 0 ? NSUnderlineStyle.single.rawValue : 0)
            }
        }

        private func adjustFontSize(by delta: CGFloat) {
            transformFonts { font in
                NSFontManager.shared.convert(font, toSize: min(max(font.pointSize + delta, 6), 144))
            }
        }

        private func toggleScript(_ value: Int) {
            guard let textView, let storage = textView.textStorage else { return }
            let key = NSAttributedString.Key.superscript
            let range = effectiveFormattingRange(in: textView, storage: storage)
            let current = range.length > 0
                ? (storage.attribute(key, at: range.location, effectiveRange: nil) as? Int ?? 0)
                : (textView.typingAttributes[key] as? Int ?? 0)
            performMutation(actionName: value > 0 ? "Superscript" : "Subscript") {
                self.applyAttributeWithoutCommit(key, value: current == value ? 0 : value)
            }
        }

        private func applyHeading(_ level: Int) {
            let size: CGFloat
            let shouldBold: Bool
            switch level {
            case 1: (size, shouldBold) = (32, true)
            case 2: (size, shouldBold) = (26, true)
            case 3: (size, shouldBold) = (22, true)
            default: (size, shouldBold) = (19, false)
            }

            performMutation(actionName: level == 0 ? "Normal Text" : "Heading \(level)") {
                guard let textView, let storage = textView.textStorage else { return }
                let range = self.paragraphRange(in: textView, storage: storage)
                storage.enumerateAttribute(.font, in: range) { value, attributeRange, _ in
                    let oldFont = value as? NSFont ?? .systemFont(ofSize: 19)
                    let family = oldFont.familyName ?? NSFont.systemFont(ofSize: size).familyName ?? "Helvetica"
                    let font = NSFontManager.shared.convert(
                        NSFontManager.shared.convert(oldFont, toFamily: family),
                        toSize: size
                    )
                    let result = NSFontManager.shared.convert(
                        font,
                        toHaveTrait: shouldBold ? .boldFontMask : .unboldFontMask
                    )
                    storage.addAttribute(.font, value: result, range: attributeRange)
                }
            }
        }

        private func copySelectedFormatting() {
            guard let textView, let storage = textView.textStorage, storage.length > 0 else { return }
            cancelFormattingPreview()
            let location = min(textView.selectedRange().location, storage.length - 1)
            copiedFormatting = storage.attributes(at: location, effectiveRange: nil).filter {
                $0.key != .attachment
            }
        }

        private func pasteCopiedFormatting() {
            guard let copiedFormatting else { return }
            performMutation(actionName: "Paste Formatting") {
                guard let textView, let storage = textView.textStorage else { return }
                let range = self.effectiveFormattingRange(in: textView, storage: storage)
                if range.length == 0 {
                    textView.typingAttributes.merge(copiedFormatting) { _, new in new }
                } else {
                    for (key, value) in copiedFormatting {
                        storage.addAttribute(key, value: value, range: range)
                    }
                }
            }
        }

        private func clearSelectedFormatting() {
            performMutation(actionName: "Clear Formatting") {
                guard let textView, let storage = textView.textStorage else { return }
                let range = self.effectiveFormattingRange(in: textView, storage: storage)
                if range.length == 0 {
                    textView.typingAttributes = Self.defaultAttributes
                    return
                }
                storage.addAttributes(Self.defaultAttributes, range: range)
                for key in [NSAttributedString.Key.underlineStyle, .strikethroughStyle, .superscript, .baselineOffset, .backgroundColor] {
                    storage.removeAttribute(key, range: range)
                }
                let paragraphRange = self.paragraphRange(in: textView, storage: storage)
                storage.addAttribute(.paragraphStyle, value: NSParagraphStyle.default, range: paragraphRange)
            }
        }

        private func applyAlignment(_ alignment: NSTextAlignment) {
            mutateParagraphs(actionName: "Align Text") { style in
                style.alignment = alignment
            }
        }

        private func applyList(markerFormat: NSTextList.MarkerFormat) {
            mutateParagraphs(actionName: "Format List") { style in
                let alreadyApplied = style.textLists.first?.markerFormat == markerFormat
                style.textLists = alreadyApplied ? [] : [NSTextList(markerFormat: markerFormat, options: 0)]
                style.headIndent = alreadyApplied ? 0 : 24
                style.firstLineHeadIndent = 0
            }
        }

        private func adjustIndent(by delta: CGFloat) {
            mutateParagraphs(actionName: delta > 0 ? "Indent" : "Outdent") { style in
                style.headIndent = max(0, style.headIndent + delta)
                if style.textLists.isEmpty {
                    style.firstLineHeadIndent = max(0, style.firstLineHeadIndent + delta)
                }
            }
        }

        private func mutateParagraphs(actionName: String, mutation: @escaping (NSMutableParagraphStyle) -> Void) {
            performMutation(actionName: actionName) {
                guard let textView, let storage = textView.textStorage else { return }
                let range = self.paragraphRange(in: textView, storage: storage)
                storage.enumerateAttribute(.paragraphStyle, in: range) { value, attributeRange, _ in
                    let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                        ?? NSMutableParagraphStyle()
                    mutation(style)
                    storage.addAttribute(.paragraphStyle, value: style, range: attributeRange)
                }
            }
        }

        private func effectiveFormattingRange(in textView: NSTextView, storage: NSTextStorage) -> NSRange {
            let selection = textView.selectedRange()
            guard selection.length == 0, storage.length > 0 else { return selection }
            return NSRange(location: min(selection.location, storage.length - 1), length: 0)
        }

        private func paragraphRange(in textView: NSTextView, storage: NSTextStorage) -> NSRange {
            let selection = textView.selectedRange()
            let safeLocation = min(selection.location, storage.length)
            return (storage.string as NSString).paragraphRange(
                for: NSRange(location: safeLocation, length: min(selection.length, storage.length - safeLocation))
            )
        }

        func insertImage() {
            guard let textView else {
                return
            }

            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.image]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.prompt = "Insert"
            panel.message = "Choose a still image to insert into this encrypted note."

            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }

            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
                    parent.onError("That file is not a supported image.")
                    return
                }

                let attachmentID = UUID().uuidString
                let pathExtension = url.pathExtension.isEmpty ? "image" : url.pathExtension.lowercased()
                let fileWrapper = FileWrapper(regularFileWithContents: data)
                fileWrapper.preferredFilename = "\(attachmentID).\(pathExtension)"
                let attachment = NSTextAttachment(fileWrapper: fileWrapper)
                attachmentIDsByObject[ObjectIdentifier(attachment)] = attachmentID
                imageSourcesByID[attachmentID] = VaultImageSource(
                    id: attachmentID,
                    data: data,
                    typeIdentifier: UTType(filenameExtension: pathExtension)?.identifier ?? UTType.image.identifier,
                    filenameExtension: pathExtension
                )

                let widthFraction = 0.50
                imageDisplayWidths[attachmentID] = widthFraction
                setBounds(for: attachment, imageSize: image.size, widthFraction: widthFraction)

                performMutation(actionName: "Insert Image") {
                    let replacement = NSAttributedString(attachment: attachment)
                    let selection = textView.selectedRange()
                    textView.textStorage?.replaceCharacters(in: selection, with: replacement)
                    textView.setSelectedRange(NSRange(location: selection.location + 1, length: 0))
                }
            } catch {
                parent.onError("The image could not be read.")
            }
        }

        func applySelectedImageWidth(_ fraction: Double) {
            guard let textView,
                  let (attachmentID, attachment) = selectedAttachment(in: textView)
            else {
                return
            }

            let clamped = min(max(fraction, 0.10), 1)
            performMutation(actionName: "Resize Image") {
                imageDisplayWidths[attachmentID] = clamped
                if let imageSize = imageSize(for: attachment) {
                    setBounds(for: attachment, imageSize: imageSize, widthFraction: clamped)
                }
                textView.layoutManager?.invalidateLayout(
                    forCharacterRange: textView.selectedRange(),
                    actualCharacterRange: nil
                )
            }
        }

        func focusEditor() {
            guard let textView else {
                return
            }
            textView.window?.makeFirstResponder(textView)
        }

        func clearEditor() {
            isLoading = true
            textView?.textStorage?.setAttributedString(NSAttributedString())
            imageDisplayWidths.removeAll(keepingCapacity: false)
            attachmentIDsByObject.removeAll(keepingCapacity: false)
            imageSourcesByID.removeAll(keepingCapacity: false)
            textView?.selectedImageCharacterIndex = nil
            textView?.selectedImageWidthFraction = nil
            loadedNoteID = nil
            isLoading = false
        }

        func updateAttachmentBounds() {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            let fullRange = NSRange(location: 0, length: storage.length)
            storage.enumerateAttribute(.attachment, in: fullRange) { value, _, _ in
                guard let attachment = value as? NSTextAttachment,
                      let attachmentID = attachmentID(for: attachment),
                      let imageSize = imageSize(for: attachment)
                else {
                    return
                }

                let fraction = imageDisplayWidths[attachmentID] ?? 1
                setBounds(for: attachment, imageSize: imageSize, widthFraction: fraction)
            }
            textView.layoutManager?.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            textView.needsDisplay = true
        }

        private func transformFonts(_ transform: (NSFont) -> NSFont) {
            performMutation(actionName: "Format Text") {
                self.transformFontsWithoutCommit(transform)
            }
        }

        private func applyAttribute(_ key: NSAttributedString.Key, value: Any) {
            performMutation(actionName: "Format Text") {
                self.applyAttributeWithoutCommit(key, value: value)
            }
        }

        private func transformFontsWithoutCommit(_ transform: (NSFont) -> NSFont) {
            guard let textView else { return }
            let selection = textView.selectedRange()
            if selection.length == 0 {
                var attributes = textView.typingAttributes
                let font = attributes[.font] as? NSFont ?? .systemFont(ofSize: 19)
                attributes[.font] = transform(font)
                textView.typingAttributes = attributes
                return
            }

            textView.textStorage?.enumerateAttribute(.font, in: selection) { value, range, _ in
                let font = value as? NSFont ?? .systemFont(ofSize: 19)
                textView.textStorage?.addAttribute(.font, value: transform(font), range: range)
            }
        }

        private func applyAttributeWithoutCommit(_ key: NSAttributedString.Key, value: Any) {
            guard let textView else { return }
            let selection = textView.selectedRange()
            if selection.length == 0 {
                var attributes = textView.typingAttributes
                attributes[key] = value
                textView.typingAttributes = attributes
            } else {
                textView.textStorage?.addAttribute(key, value: value, range: selection)
            }
        }

        private func previewFormatting(actionName: String, mutation: () -> Void) {
            guard let textView, let storage = textView.textStorage else { return }
            if let preview = formattingPreview {
                restorePreview(preview)
            } else {
                formattingPreview = FormattingPreview(
                    attributedString: NSAttributedString(attributedString: storage),
                    typingAttributes: textView.typingAttributes,
                    selection: textView.selectedRange(),
                    imageDisplayWidths: imageDisplayWidths,
                    actionName: actionName
                )
            }

            storage.beginEditing()
            mutation()
            storage.endEditing()
            updateSelectionState()
        }

        private func restorePreview(_ preview: FormattingPreview) {
            guard let textView, let storage = textView.textStorage else { return }
            isLoading = true
            storage.setAttributedString(preview.attributedString)
            textView.typingAttributes = preview.typingAttributes
            textView.setSelectedRange(preview.selection)
            imageDisplayWidths = preview.imageDisplayWidths
            isLoading = false
        }

        private func performMutation(actionName: String, mutation: () -> Void) {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            cancelFormattingPreview()

            let before = NSAttributedString(attributedString: storage)
            let beforeWidths = imageDisplayWidths
            let beforeSelection = textView.selectedRange()
            registerUndo(
                attributedString: before,
                imageDisplayWidths: beforeWidths,
                selection: beforeSelection,
                actionName: actionName
            )
            textView.undoManager?.setActionName(actionName)

            storage.beginEditing()
            mutation()
            storage.endEditing()
            emitChange()
            updateSelectionState()
        }

        private func registerUndo(
            attributedString: NSAttributedString,
            imageDisplayWidths: [String: Double],
            selection: NSRange,
            actionName: String
        ) {
            textView?.undoManager?.registerUndo(withTarget: self) { target in
                target.restore(
                    attributedString: attributedString,
                    imageDisplayWidths: imageDisplayWidths,
                    selection: selection,
                    actionName: actionName
                )
            }
        }

        private func restore(
            attributedString: NSAttributedString,
            imageDisplayWidths: [String: Double],
            selection: NSRange,
            actionName: String
        ) {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            let current = NSAttributedString(attributedString: storage)
            let currentWidths = self.imageDisplayWidths
            let currentSelection = textView.selectedRange()
            textView.undoManager?.registerUndo(withTarget: self) { target in
                target.restore(
                    attributedString: current,
                    imageDisplayWidths: currentWidths,
                    selection: currentSelection,
                    actionName: actionName
                )
            }

            isLoading = true
            storage.setAttributedString(attributedString)
            self.imageDisplayWidths = imageDisplayWidths
            textView.setSelectedRange(selection)
            updateAttachmentBounds()
            isLoading = false
            emitChange()
            updateSelectionState()
        }

        private func emitChange() {
            guard !isLoading,
                  let textView,
                  let storage = textView.textStorage,
                  let rtfdData = storage.rtfd(
                    from: NSRange(location: 0, length: storage.length),
                    documentAttributes: [:]
                  )
            else {
                return
            }

            let plainText = storage.string.replacingOccurrences(of: "\u{FFFC}", with: "")
            parent.onChange(
                plainText,
                VaultRichContent(
                    rtfdData: rtfdData,
                    imageAttachmentIDs: currentAttachmentIDs(),
                    imageDisplayWidths: persistedImageDisplayWidths(),
                    imageSources: currentAttachmentIDs().compactMap { imageSourcesByID[$0] }
                )
            )
        }

        private func updateSelectionState() {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            let selection = textView.selectedRange()
            let inspectionRange: NSRange
            if selection.length > 0 {
                inspectionRange = selection
            } else if storage.length > 0 {
                inspectionRange = NSRange(location: min(selection.location, storage.length - 1), length: 1)
            } else {
                inspectionRange = NSRange(location: 0, length: 0)
            }

            var fonts: [NSFont] = []
            var colors: [NSColor] = []
            if inspectionRange.length > 0 {
                storage.enumerateAttributes(in: inspectionRange) { attributes, _, _ in
                    if attributes[.attachment] == nil {
                        fonts.append(attributes[.font] as? NSFont ?? .systemFont(ofSize: 19))
                        colors.append(attributes[.foregroundColor] as? NSColor ?? .writerPaperInk)
                    }
                }
            }

            if fonts.isEmpty {
                let attributes = textView.typingAttributes
                fonts = [attributes[.font] as? NSFont ?? .systemFont(ofSize: 19)]
                colors = [attributes[.foregroundColor] as? NSColor ?? .writerPaperInk]
            }

            let fontManager = NSFontManager.shared
            let fontFamilies = fonts.map { $0.familyName ?? $0.fontName }
            let fontSizes = fonts.map { Double($0.pointSize) }
            let boldValues = fonts.map { fontManager.traits(of: $0).contains(.boldFontMask) }
            let italicValues = fonts.map { fontManager.traits(of: $0).contains(.italicFontMask) }
            let selectedWidth = selectedAttachment(in: textView).flatMap { imageDisplayWidths[$0.0] }

            parent.context.update(
                fontFamily: uniformValue(in: fontFamilies),
                fontSize: uniformValue(in: fontSizes),
                isBold: uniformValue(in: boldValues),
                isItalic: uniformValue(in: italicValues),
                textColor: colors.first ?? .writerPaperInk,
                selectedImageWidth: selectedWidth
            )

            if let location = selectedAttachmentLocation(in: textView), let selectedWidth {
                textView.selectedImageCharacterIndex = location
                textView.selectedImageWidthFraction = selectedWidth
            } else {
                textView.selectedImageCharacterIndex = nil
                textView.selectedImageWidthFraction = nil
            }
        }

        private func selectImage(at location: Int) {
            guard let textView,
                  textView.textStorage?.attribute(.attachment, at: location, effectiveRange: nil) is NSTextAttachment
            else { return }
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: location, length: 1))
            updateSelectionState()
        }

        private func deleteImage(at location: Int) {
            guard let textView,
                  let storage = textView.textStorage,
                  location >= 0,
                  location < storage.length,
                  let attachment = storage.attribute(.attachment, at: location, effectiveRange: nil) as? NSTextAttachment,
                  let attachmentID = attachmentID(for: attachment)
            else { return }

            textView.setSelectedRange(NSRange(location: location, length: 1))
            performMutation(actionName: "Delete Image") {
                storage.deleteCharacters(in: NSRange(location: location, length: 1))
                imageDisplayWidths.removeValue(forKey: attachmentID)
                textView.setSelectedRange(NSRange(location: min(location, storage.length), length: 0))
            }
        }

        private func beginImageResize(at location: Int) {
            guard let textView,
                  let storage = textView.textStorage,
                  location >= 0,
                  location < storage.length,
                  storage.attribute(.attachment, at: location, effectiveRange: nil) is NSTextAttachment
            else { return }

            textView.setSelectedRange(NSRange(location: location, length: 1))
            // Register one undo snapshot for the entire drag gesture. Subsequent
            // mouse-drag updates only adjust the attachment's presentation.
            performMutation(actionName: "Resize Image") {}
        }

        private func resizeImage(at location: Int, to fraction: Double) {
            guard let textView,
                  let storage = textView.textStorage,
                  location >= 0,
                  location < storage.length,
                  let attachment = storage.attribute(.attachment, at: location, effectiveRange: nil) as? NSTextAttachment,
                  let attachmentID = attachmentID(for: attachment),
                  let imageSize = imageSize(for: attachment)
            else { return }

            let clamped = min(max(fraction, 0.10), 1)
            imageDisplayWidths[attachmentID] = clamped
            setBounds(for: attachment, imageSize: imageSize, widthFraction: clamped)
            textView.layoutManager?.invalidateLayout(
                forCharacterRange: NSRange(location: location, length: 1),
                actualCharacterRange: nil
            )
            textView.selectedImageWidthFraction = clamped
            textView.needsDisplay = true
            emitChange()
            updateSelectionState()
        }

        private func uniformValue(in values: [Bool]) -> Bool? {
            guard let first = values.first, values.allSatisfy({ $0 == first }) else {
                return nil
            }
            return first
        }

        private func uniformValue<T: Equatable>(in values: [T]) -> T? {
            guard let first = values.first, values.allSatisfy({ $0 == first }) else {
                return nil
            }
            return first
        }

        private func assignAttachmentIdentifiers(_ savedIdentifiers: [String]) {
            guard let storage = textView?.textStorage else {
                return
            }

            var attachmentIndex = 0
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.enumerateAttribute(.attachment, in: fullRange) { value, _, _ in
                guard let attachment = value as? NSTextAttachment else {
                    return
                }

                let savedIdentifier = attachmentIndex < savedIdentifiers.count
                    ? savedIdentifiers[attachmentIndex]
                    : nil
                let wrapperIdentifier = attachment.fileWrapper?.preferredFilename.map {
                    URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
                }
                attachmentIDsByObject[ObjectIdentifier(attachment)] = savedIdentifier
                    ?? wrapperIdentifier
                    ?? UUID().uuidString
                attachmentIndex += 1
            }
        }

        private func rebuildAttachmentsFromOriginalSources(_ savedIdentifiers: [String]) {
            guard let storage = textView?.textStorage else {
                return
            }

            var attachmentRanges: [NSRange] = []
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
                if value as? NSTextAttachment != nil {
                    attachmentRanges.append(range)
                }
            }

            for (index, range) in attachmentRanges.enumerated() where index < savedIdentifiers.count {
                let identifier = savedIdentifiers[index]
                guard let source = imageSourcesByID[identifier] else {
                    continue
                }
                let wrapper = FileWrapper(regularFileWithContents: source.data)
                wrapper.preferredFilename = "\(identifier).\(source.filenameExtension)"
                let attachment = NSTextAttachment(fileWrapper: wrapper)
                storage.addAttribute(.attachment, value: attachment, range: range)
            }
        }

        private func persistedImageDisplayWidths() -> [String: Double] {
            guard let storage = textView?.textStorage else {
                return [:]
            }

            var attachmentIDs = Set<String>()
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.enumerateAttribute(.attachment, in: fullRange) { value, _, _ in
                guard let attachment = value as? NSTextAttachment,
                      let identifier = attachmentID(for: attachment)
                else {
                    return
                }
                attachmentIDs.insert(identifier)
            }

            return imageDisplayWidths.filter { attachmentIDs.contains($0.key) }
        }

        private func currentAttachmentIDs() -> [String] {
            guard let storage = textView?.textStorage else {
                return []
            }

            var identifiers: [String] = []
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.enumerateAttribute(.attachment, in: fullRange) { value, _, _ in
                guard let attachment = value as? NSTextAttachment,
                      let identifier = attachmentID(for: attachment)
                else {
                    return
                }
                identifiers.append(identifier)
            }
            return identifiers
        }

        private func selectedAttachment(in textView: NSTextView) -> (String, NSTextAttachment)? {
            guard let storage = textView.textStorage, storage.length > 0 else {
                return nil
            }

            let selection = textView.selectedRange()
            let candidateLocations: [Int]
            if selection.length == 1 {
                candidateLocations = [selection.location]
            } else if selection.length > 1 {
                return nil
            } else {
                candidateLocations = [selection.location, selection.location - 1]
                    .filter { $0 >= 0 && $0 < storage.length }
            }

            for location in candidateLocations {
                if let attachment = storage.attribute(.attachment, at: location, effectiveRange: nil) as? NSTextAttachment,
                   let identifier = attachmentID(for: attachment) {
                    return (identifier, attachment)
                }
            }
            return nil
        }

        private func selectedAttachmentLocation(in textView: NSTextView) -> Int? {
            guard let storage = textView.textStorage, storage.length > 0 else { return nil }

            let selection = textView.selectedRange()
            let candidateLocations: [Int]
            if selection.length == 1 {
                candidateLocations = [selection.location]
            } else if selection.length > 1 {
                return nil
            } else {
                candidateLocations = [selection.location, selection.location - 1]
                    .filter { $0 >= 0 && $0 < storage.length }
            }

            return candidateLocations.first {
                storage.attribute(.attachment, at: $0, effectiveRange: nil) is NSTextAttachment
            }
        }

        private func attachmentID(for attachment: NSTextAttachment) -> String? {
            let objectIdentifier = ObjectIdentifier(attachment)
            if let identifier = attachmentIDsByObject[objectIdentifier] {
                return identifier
            }

            let wrapperIdentifier = attachment.fileWrapper?.preferredFilename.map {
                URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
            }
            let identifier = wrapperIdentifier?.isEmpty == false ? wrapperIdentifier! : UUID().uuidString
            attachmentIDsByObject[objectIdentifier] = identifier
            return identifier
        }

        private func imageSize(for attachment: NSTextAttachment) -> NSSize? {
            guard let data = attachment.fileWrapper?.regularFileContents ?? attachment.contents,
                  let image = NSImage(data: data),
                  image.size.width > 0,
                  image.size.height > 0
            else {
                return nil
            }
            return image.size
        }

        private func setBounds(for attachment: NSTextAttachment, imageSize: NSSize, widthFraction: Double) {
            let width = max(textContainerWidth() * widthFraction, 1)
            let height = width * imageSize.height / imageSize.width
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        }

        private func textContainerWidth() -> CGFloat {
            guard let textView else {
                return 600
            }
            let viewportWidth = textView.enclosingScrollView?.contentSize.width ?? textView.bounds.width
            let availableWidth = min(textView.bounds.width, viewportWidth)
            let linePadding = (textView.textContainer?.lineFragmentPadding ?? 0) * 2
            return max(availableWidth - (textView.textContainerInset.width * 2) - linePadding, 1)
        }
    }
}

final class WriterTextView: NSTextView {
    var selectedImageCharacterIndex: Int? {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }
    var selectedImageWidthFraction: Double? {
        didSet { needsDisplay = true }
    }

    var onSelectImage: ((Int) -> Void)?
    var onDeleteImage: ((Int) -> Void)?
    var onBeginImageResize: ((Int) -> Void)?
    var onResizeImage: ((Int, Double) -> Void)?
    var onViewportWidthChange: (() -> Void)?
    var onFormattingCommand: ((EditorFormattingCommand) -> Void)?

    private var activeResize: ActiveResize?

    override func setFrameSize(_ newSize: NSSize) {
        let oldWidth = frame.width
        super.setFrameSize(newSize)

        guard newSize.width > 0, abs(newSize.width - oldWidth) > 0.5 else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onViewportWidthChange?()
        }
    }

    override func paste(_ sender: Any?) {
        guard let string = NSPasteboard.general.string(forType: .string) else {
            return
        }
        insertText(string, replacementRange: selectedRange())
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let character = event.charactersIgnoringModifiers?.lowercased()
        let command: EditorFormattingCommand?

        switch (flags, character) {
        case ([.command], "b"): command = .toggleBold
        case ([.command], "i"): command = .toggleItalic
        case ([.command], "u"): command = .toggleUnderline
        case ([.command, .shift], "x"): command = .toggleStrikethrough
        case ([.command, .option], "0"): command = .heading(0)
        case ([.command, .option], "1"): command = .heading(1)
        case ([.command, .option], "2"): command = .heading(2)
        case ([.command, .option], "3"): command = .heading(3)
        case ([.command, .option], "c"): command = .copyFormatting
        case ([.command, .option], "v"): command = .pasteFormatting
        case ([.command], "\\"): command = .clearFormatting
        case ([.command, .shift], "."): command = .increaseFontSize
        case ([.command, .shift], ","): command = .decreaseFontSize
        case ([.command], ","): command = .subscriptText
        case ([.command], "."): command = .superscriptText
        case ([.command, .shift], "l"): command = .alignLeft
        case ([.command, .shift], "e"): command = .alignCenter
        case ([.command, .shift], "r"): command = .alignRight
        case ([.command, .shift], "j"): command = .justify
        case ([.command, .shift], "8"): command = .bulletedList
        case ([.command, .shift], "7"): command = .numberedList
        default: command = nil
        }

        guard let command else {
            return super.performKeyEquivalent(with: event)
        }
        onFormattingCommand?(command)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 48, isSelectionInList else {
            super.keyDown(with: event)
            return
        }
        let isOutdent = event.modifierFlags.contains(.shift)
        onFormattingCommand?(isOutdent ? .outdent : .indent)
    }

    private var isSelectionInList: Bool {
        guard let textStorage, textStorage.length > 0 else { return false }
        let location = min(selectedRange().location, textStorage.length - 1)
        let style = textStorage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        return style?.textLists.isEmpty == false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let location = selectedImageCharacterIndex,
              let imageRect = attachmentRect(at: location)
        else { return }

        NSGraphicsContext.saveGraphicsState()

        NSColor.controlAccentColor.setStroke()
        let outline = NSBezierPath(roundedRect: imageRect.insetBy(dx: -2, dy: -2), xRadius: 3, yRadius: 3)
        outline.lineWidth = 2
        outline.stroke()

        for handle in ResizeHandle.allCases {
            let rect = handleRect(for: handle, imageRect: imageRect)
            NSColor.white.setFill()
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.lineWidth = 1.5
            path.fill()
            path.stroke()
        }

        let closeRect = closeButtonRect(for: imageRect)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: closeRect).fill()
        NSColor.white.setStroke()
        let inset = closeRect.insetBy(dx: 6.5, dy: 6.5)
        let closePath = NSBezierPath()
        closePath.lineWidth = 2
        closePath.lineCapStyle = .round
        closePath.move(to: NSPoint(x: inset.minX, y: inset.minY))
        closePath.line(to: NSPoint(x: inset.maxX, y: inset.maxY))
        closePath.move(to: NSPoint(x: inset.maxX, y: inset.minY))
        closePath.line(to: NSPoint(x: inset.minX, y: inset.maxY))
        closePath.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let location = selectedImageCharacterIndex,
           let imageRect = attachmentRect(at: location) {
            if closeButtonHitRect(for: imageRect).contains(point) {
                onDeleteImage?(location)
                return
            }

            if let handle = resizeHandle(at: point, imageRect: imageRect),
               let initialFraction = selectedImageWidthFraction {
                activeResize = ActiveResize(
                    location: location,
                    handle: handle,
                    initialPoint: point,
                    initialImageRect: imageRect,
                    initialWidthFraction: initialFraction
                )
                onBeginImageResize?(location)
                return
            }
        }

        if let location = attachmentLocation(at: point) {
            onSelectImage?(location)
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let activeResize else {
            super.mouseDragged(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - activeResize.initialPoint.x
        let deltaY = point.y - activeResize.initialPoint.y
        let aspect = activeResize.initialImageRect.width / max(activeResize.initialImageRect.height, 1)
        let widthDelta = activeResize.handle.widthDelta(
            horizontal: deltaX,
            vertical: deltaY,
            aspect: aspect
        )
        let proposedWidth = max(activeResize.initialImageRect.width + widthDelta, 1)
        let proposedFraction = activeResize.initialWidthFraction
            * Double(proposedWidth / max(activeResize.initialImageRect.width, 1))
        onResizeImage?(activeResize.location, min(max(proposedFraction, 0.10), 1))
    }

    override func mouseUp(with event: NSEvent) {
        if activeResize != nil {
            activeResize = nil
            return
        }
        super.mouseUp(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let location = selectedImageCharacterIndex,
              let imageRect = attachmentRect(at: location)
        else { return }

        addCursorRect(closeButtonHitRect(for: imageRect), cursor: .pointingHand)
        for handle in ResizeHandle.allCases {
            let cursor: NSCursor = handle.isHorizontalEdge ? .resizeLeftRight : .resizeUpDown
            addCursorRect(handleHitRect(for: handle, imageRect: imageRect), cursor: cursor)
        }
    }

    private func attachmentLocation(at point: NSPoint) -> Int? {
        guard let storage = textStorage else { return nil }
        var match: Int?
        storage.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: storage.length),
            options: [.longestEffectiveRangeNotRequired]
        ) { value, range, stop in
            guard value is NSTextAttachment,
                  let rect = attachmentRect(at: range.location),
                  rect.contains(point)
            else { return }
            match = range.location
            stop.pointee = true
        }
        return match
    }

    private func attachmentRect(at characterIndex: Int) -> NSRect? {
        guard let layoutManager,
              let textContainer,
              let storage = textStorage,
              characterIndex >= 0,
              characterIndex < storage.length,
              storage.attribute(.attachment, at: characterIndex, effectiveRange: nil) is NSTextAttachment
        else { return nil }

        let characterRange = NSRange(location: characterIndex, length: 1)
        layoutManager.ensureLayout(forCharacterRange: characterRange)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    private func closeButtonRect(for imageRect: NSRect) -> NSRect {
        NSRect(x: imageRect.maxX - 30, y: imageRect.minY + 8, width: 24, height: 24)
    }

    private func closeButtonHitRect(for imageRect: NSRect) -> NSRect {
        closeButtonRect(for: imageRect).insetBy(dx: -4, dy: -4)
    }

    private func handleRect(for handle: ResizeHandle, imageRect: NSRect) -> NSRect {
        let point = handle.point(in: imageRect)
        return NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
    }

    private func handleHitRect(for handle: ResizeHandle, imageRect: NSRect) -> NSRect {
        handleRect(for: handle, imageRect: imageRect).insetBy(dx: -6, dy: -6)
    }

    private func resizeHandle(at point: NSPoint, imageRect: NSRect) -> ResizeHandle? {
        ResizeHandle.allCases.first {
            handleHitRect(for: $0, imageRect: imageRect).contains(point)
        }
    }

    private struct ActiveResize {
        let location: Int
        let handle: ResizeHandle
        let initialPoint: NSPoint
        let initialImageRect: NSRect
        let initialWidthFraction: Double
    }

    private enum ResizeHandle: CaseIterable {
        case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

        var isHorizontalEdge: Bool {
            self == .left || self == .right
        }

        func point(in rect: NSRect) -> NSPoint {
            switch self {
            case .topLeft: return NSPoint(x: rect.minX, y: rect.minY)
            case .top: return NSPoint(x: rect.midX, y: rect.minY)
            case .topRight: return NSPoint(x: rect.maxX, y: rect.minY)
            case .left: return NSPoint(x: rect.minX, y: rect.midY)
            case .right: return NSPoint(x: rect.maxX, y: rect.midY)
            case .bottomLeft: return NSPoint(x: rect.minX, y: rect.maxY)
            case .bottom: return NSPoint(x: rect.midX, y: rect.maxY)
            case .bottomRight: return NSPoint(x: rect.maxX, y: rect.maxY)
            }
        }

        func widthDelta(horizontal: CGFloat, vertical: CGFloat, aspect: CGFloat) -> CGFloat {
            let horizontalDelta: CGFloat?
            let verticalDelta: CGFloat?
            switch self {
            case .topLeft, .left, .bottomLeft: horizontalDelta = -horizontal
            case .topRight, .right, .bottomRight: horizontalDelta = horizontal
            case .top, .bottom: horizontalDelta = nil
            }
            switch self {
            case .topLeft, .top, .topRight: verticalDelta = -vertical * aspect
            case .bottomLeft, .bottom, .bottomRight: verticalDelta = vertical * aspect
            case .left, .right: verticalDelta = nil
            }

            switch (horizontalDelta, verticalDelta) {
            case let (horizontal?, vertical?):
                return abs(horizontal) >= abs(vertical) ? horizontal : vertical
            case let (horizontal?, nil):
                return horizontal
            case let (nil, vertical?):
                return vertical
            default:
                return 0
            }
        }
    }
}

extension NSColor {
    static let writerPaperInk = NSColor(
        calibratedRed: 0.035,
        green: 0.045,
        blue: 0.055,
        alpha: 1
    )
}
