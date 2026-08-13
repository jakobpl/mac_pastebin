import Foundation
import XCTest
@testable import writer

@MainActor
final class AppStateTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    func testNotesAreOrderedByMostRecentActivity() throws {
        let service = makeService()
        let password = "a unique ordering test passphrase"
        let unlockResult = try service.createVault(password: password)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let olderNote = VaultNote(
            id: "older",
            title: "Older",
            body: "Old body",
            createdAt: baseDate,
            updatedAt: baseDate,
            isTitleFinalized: true
        )
        let newerNote = VaultNote(
            id: "newer",
            title: "Newer",
            body: "New body",
            createdAt: baseDate.addingTimeInterval(60),
            updatedAt: baseDate.addingTimeInterval(120),
            isTitleFinalized: true
        )
        try service.savePayload(
            VaultPayload(
                formatVersion: 2,
                notes: [olderNote, newerNote],
                selectedNoteID: olderNote.id
            ),
            using: unlockResult.key
        )

        let appState = AppState(vaultService: service)
        appState.createOrUnlockVault(password: password)

        XCTAssertEqual(appState.notes.map(\.id), [newerNote.id, olderNote.id])
        XCTAssertEqual(appState.selectedNoteID, olderNote.id)

        appState.createNote()
        let createdNoteID = try XCTUnwrap(appState.selectedNoteID)
        XCTAssertEqual(appState.notes.first?.id, createdNoteID)

        appState.selectNote(id: olderNote.id)
        appState.updateSelectedNoteBody("Edited old body")
        XCTAssertEqual(appState.notes.first?.id, olderNote.id)

        appState.selectNote(id: newerNote.id)
        appState.updateSelectedNoteContent(
            body: "Edited rich body",
            richContent: VaultRichContent(rtfdData: Data())
        )
        XCTAssertEqual(appState.notes.first?.id, newerNote.id)
    }

    private func makeService() -> VaultService {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("writer-app-state-tests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(directory)
        return VaultService(
            applicationSupportDirectory: directory,
            newVaultIterationCount: 1
        )
    }
}
