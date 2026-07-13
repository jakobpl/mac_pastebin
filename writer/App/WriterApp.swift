import AppKit
import SwiftUI

@main
struct WriterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("Writer", id: "main") {
            AppRootView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    appState.lock()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                    if !NSApplication.shared.isActive {
                        appState.lock()
                    }
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appState.createNote()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(appState.isLocked)
            }
        }
    }
}
