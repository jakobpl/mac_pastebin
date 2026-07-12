import Foundation

struct VaultPayload: Codable, Equatable {
    let formatVersion: Int
    let notes: [VaultNote]
    let selectedNoteID: String?

    static func singleEditorNote(body: String, now: Date = Date()) -> VaultPayload {
        let note = VaultNote(
            id: "primary",
            title: "Untitled",
            body: body,
            createdAt: now,
            updatedAt: now,
            isTitleFinalized: false
        )

        return VaultPayload(
            formatVersion: 1,
            notes: [note],
            selectedNoteID: note.id
        )
    }

    var selectedEditorText: String {
        if let selectedNoteID,
           let selectedNote = notes.first(where: { $0.id == selectedNoteID }) {
            return selectedNote.body
        }

        return notes.first?.body ?? ""
    }
}

struct VaultNote: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var body: String
    let createdAt: Date
    var updatedAt: Date
    var isTitleFinalized: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt
        case updatedAt
        case isTitleFinalized
    }

    init(
        id: String,
        title: String,
        body: String,
        createdAt: Date,
        updatedAt: Date,
        isTitleFinalized: Bool
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTitleFinalized = isTitleFinalized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isTitleFinalized = try container.decodeIfPresent(Bool.self, forKey: .isTitleFinalized)
            ?? (title.localizedCaseInsensitiveCompare("Untitled") != .orderedSame)
    }
}
