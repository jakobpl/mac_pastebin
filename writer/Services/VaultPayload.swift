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
            formatVersion: 2,
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

struct VaultRichContent: Codable, Equatable {
    var rtfdData: Data
    var imageAttachmentIDs: [String]
    var imageDisplayWidths: [String: Double]
    var imageSources: [VaultImageSource]

    private enum CodingKeys: String, CodingKey {
        case rtfdData
        case imageAttachmentIDs
        case imageDisplayWidths
        case imageSources
    }

    init(
        rtfdData: Data,
        imageAttachmentIDs: [String] = [],
        imageDisplayWidths: [String: Double] = [:],
        imageSources: [VaultImageSource] = []
    ) {
        self.rtfdData = rtfdData
        self.imageAttachmentIDs = imageAttachmentIDs
        self.imageDisplayWidths = imageDisplayWidths
        self.imageSources = imageSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rtfdData = try container.decode(Data.self, forKey: .rtfdData)
        imageDisplayWidths = try container.decodeIfPresent(
            [String: Double].self,
            forKey: .imageDisplayWidths
        ) ?? [:]
        imageAttachmentIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .imageAttachmentIDs
        ) ?? imageDisplayWidths.keys.sorted()
        imageSources = try container.decodeIfPresent([VaultImageSource].self, forKey: .imageSources) ?? []
    }
}

struct VaultImageSource: Codable, Equatable {
    let id: String
    let data: Data
    let typeIdentifier: String
    let filenameExtension: String
}

struct VaultNote: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var body: String
    let createdAt: Date
    var updatedAt: Date
    var isTitleFinalized: Bool
    var richContent: VaultRichContent?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt
        case updatedAt
        case isTitleFinalized
        case richContent
    }

    init(
        id: String,
        title: String,
        body: String,
        createdAt: Date,
        updatedAt: Date,
        isTitleFinalized: Bool,
        richContent: VaultRichContent? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTitleFinalized = isTitleFinalized
        self.richContent = richContent
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
        richContent = try container.decodeIfPresent(VaultRichContent.self, forKey: .richContent)
    }
}
