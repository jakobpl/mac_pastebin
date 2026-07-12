import SwiftUI

struct EditorView: View {
    private enum FocusArea {
        case noteList
        case title
        case editor
    }

    @EnvironmentObject private var appState: AppState
    @State private var notePendingRename: VaultNote?
    @State private var renameTitle = ""
    @State private var notePendingDeletion: VaultNote?
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @FocusState private var focusedArea: FocusArea?

    var body: some View {
        ZStack {
            VStack(spacing: WriterLayout.sectionSpacing) {
                toolbar

                HStack(alignment: .top, spacing: 20) {
                    notesSidebar
                    editorSurface
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, WriterLayout.outerPadding)
            .padding(.top, WriterLayout.outerPadding)
            .padding(.bottom, 24)
        }
        .onAppear {
            focusedArea = .editor
            titleDraft = selectedNoteTitle
        }
        .onChange(of: focusedArea) { oldFocus, newFocus in
            if oldFocus == .title && newFocus != .title {
                commitTitleEditing()
            }
        }
        .onChange(of: appState.selectedNoteID) { _, _ in
            if !isEditingTitle {
                titleDraft = selectedNoteTitle
            }
        }
        .onMoveCommand { direction in
            guard focusedArea == .noteList else {
                return
            }

            switch direction {
            case .up:
                appState.selectPreviousNote()
            case .down:
                appState.selectNextNote()
            default:
                break
            }
        }
        .sheet(item: $notePendingRename) { note in
            VStack(alignment: .leading, spacing: 12) {
                Text("Rename Note")
                    .font(.headline)

                TextField("Title", text: $renameTitle)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()

                    Button("Cancel") {
                        notePendingRename = nil
                    }

                    Button("Rename") {
                        appState.renameNote(id: note.id, title: renameTitle)
                        notePendingRename = nil
                    }
                }
            }
            .padding()
            .frame(width: 320)
        }
        .alert("Delete Note?", isPresented: deleteConfirmationBinding, presenting: notePendingDeletion) { note in
            Button("Cancel", role: .cancel) {
                notePendingDeletion = nil
            }

            Button("Delete", role: .destructive) {
                appState.deleteNote(id: note.id)
                notePendingDeletion = nil
            }
        } message: { note in
            Text("This removes \"\(note.title)\" from the vault.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Spacer()

            statusPill
            autoSavePill
            toolbarIconButton(systemImage: "doc.on.doc", help: "Copy note text") {
                appState.copySelectedNoteBodyToPasteboard()
            }
            toolbarIconButton(systemImage: "square.and.arrow.down", help: "Save vault") {
                appState.saveEditorText()
            }
            toolbarIconButton(systemImage: "lock", help: "Lock vault") {
                appState.lock()
            }

            Button("Notes") {
                focusedArea = .noteList
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            Button("Editor") {
                focusedArea = .editor
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            Button("Save") {
                appState.saveEditorText()
            }
            .keyboardShortcut("s", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusPill: some View {
        Label(statusText, systemImage: "checkmark")
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(WriterPalette.paperInk.opacity(0.88))
            .frame(height: 48)
            .padding(.horizontal, 20)
            .puffyGlassSurface(cornerRadius: 20, tintOpacity: 0.34)
    }

    private var autoSavePill: some View {
        Button {
            appState.setAutoSaveEnabled(!appState.isAutoSaveEnabled)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(appState.isAutoSaveEnabled ? WriterPalette.sage : Color.white.opacity(0.82))
                    .frame(width: 18, height: 18)
                    .overlay {
                        if appState.isAutoSaveEnabled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(WriterPalette.paperInk.opacity(0.72))
                        }
                    }

                Text("Auto Save")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(WriterPalette.paperInk.opacity(0.84))
            .frame(height: 44)
            .padding(.horizontal, 17)
        }
        .buttonStyle(.plain)
        .puffyGlassSurface(cornerRadius: 16, tintOpacity: 0.30)
        .help("Toggle auto save")
    }

    private func toolbarIconButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(WriterPalette.paperInk.opacity(0.72))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .puffyGlassSurface(cornerRadius: 16, tintOpacity: 0.30)
        .help(help)
    }

    private var notesSidebar: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center) {
                Text("Notes")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(WriterPalette.paperInk.opacity(0.86))

                Spacer()

                Button {
                    appState.createNote()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(WriterPalette.paperInk.opacity(0.78))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .puffyGlassSurface(cornerRadius: 15, tintOpacity: 0.30)
                .help("New note")
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(appState.notes) { note in
                        Button {
                            appState.selectNote(id: note.id)
                            focusedArea = .editor
                        } label: {
                            noteRow(for: note)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Rename") {
                                notePendingRename = note
                                renameTitle = note.title
                            }

                            Button("Delete", role: .destructive) {
                                notePendingDeletion = note
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .focusable()
            .focusEffectDisabled()
            .focused($focusedArea, equals: .noteList)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 22)
        .frame(width: WriterLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .liquidGlassSurface(cornerRadius: WriterLayout.panelRadius, tintOpacity: 0.26)
    }

    private func noteRow(for note: VaultNote) -> some View {
        let isSelected = note.id == appState.selectedNoteID

        return HStack(spacing: 12) {
            Image(systemName: "doc")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(WriterPalette.paperInk.opacity(isSelected ? 0.78 : 0.62))
                .frame(width: 22)

            Text(note.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(WriterPalette.paperInk.opacity(0.88))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(WriterPalette.glassTintElevated.opacity(0.36)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    }
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.44), lineWidth: 1)
            }
        }
    }

    private var editorSurface: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                editableTitleView

                Spacer()

                Text(wordCountLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(WriterPalette.paperInk.opacity(0.70))
            }
            .padding(.horizontal, 26)
            .frame(height: 78)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(WriterPalette.paper)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.58), lineWidth: 1)
                    }

                TextEditor(
                    text: Binding(
                        get: { appState.selectedNoteBody },
                        set: { appState.updateSelectedNoteBody($0) }
                    )
                )
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(WriterPalette.paperInk)
                .scrollContentBackground(.hidden)
                .padding(22)
                .focused($focusedArea, equals: .editor)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassSurface(cornerRadius: WriterLayout.panelRadius, tintOpacity: 0.28)
    }

    @ViewBuilder
    private var editableTitleView: some View {
        if isEditingTitle {
            TextField("Title", text: $titleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(WriterPalette.paperInk.opacity(0.92))
                .tint(WriterPalette.paperInk.opacity(0.78))
                .focused($focusedArea, equals: .title)
                .onSubmit(commitTitleEditing)
                .frame(minWidth: 220)
        } else {
            Button {
                beginTitleEditing()
            } label: {
                HStack(spacing: 8) {
                    Text(selectedNoteTitle)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(WriterPalette.paperInk.opacity(0.92))
                        .lineLimit(1)

                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WriterPalette.paperInk.opacity(0.50))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit title")
        }
    }

    private var selectedNoteTitle: String {
        appState.notes.first(where: { $0.id == appState.selectedNoteID })?.title ?? "Untitled"
    }

    private var statusText: String {
        guard let message = appState.editorStatusMessage else {
            return "Saved"
        }

        return message.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private var wordCountLabel: String {
        let words = appState.selectedNoteBody
            .split { $0.isWhitespace || $0.isNewline }
            .count

        return words == 1 ? "1 word" : "\(words) words"
    }

    private func beginTitleEditing() {
        titleDraft = selectedNoteTitle
        isEditingTitle = true
        focusedArea = .title
    }

    private func commitTitleEditing() {
        guard isEditingTitle else {
            return
        }

        isEditingTitle = false

        guard let selectedNoteID = appState.selectedNoteID else {
            return
        }

        appState.renameNote(id: selectedNoteID, title: titleDraft)
        titleDraft = selectedNoteTitle
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { notePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    notePendingDeletion = nil
                }
            }
        )
    }
}
