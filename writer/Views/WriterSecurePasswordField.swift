import AppKit
import SwiftUI

/// AppKit owns secure text input on macOS. Keeping the first-responder handoff
/// here avoids SwiftUI focus races when the unlock screen is first presented.
struct WriterSecurePasswordField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String
    let requestsInitialFocus: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> SecurePasswordContainer {
        let container = SecurePasswordContainer()
        let field = container.textField
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel)
        return container
    }

    func updateNSView(_ container: SecurePasswordContainer, context: Context) {
        context.coordinator.parent = self

        let field = container.textField
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel)
        container.requestsInitialFocus = requestsInitialFocus
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: WriterSecurePasswordField

        init(parent: WriterSecurePasswordField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSecureTextField else { return }
            parent.text = field.stringValue
        }

        @objc func submit(_ sender: NSSecureTextField) {
            parent.text = sender.stringValue
            parent.onSubmit()
        }
    }
}

final class SecurePasswordContainer: NSView {
    let textField = ReactivatingSecureTextField()

    var requestsInitialFocus = false {
        didSet {
            requestInitialFocusIfNeeded()
        }
    }

    private var focusRequestIsPending = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isBezeled = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 20, weight: .regular)
        textField.textColor = NSColor.labelColor.withAlphaComponent(0.70)

        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 28)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestInitialFocusIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(textField)
    }

    private func requestInitialFocusIfNeeded() {
        guard requestsInitialFocus, !focusRequestIsPending, window != nil else { return }
        focusRequestIsPending = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.focusRequestIsPending = false
            guard
                self.requestsInitialFocus,
                let window = self.window,
                NSApp.isActive,
                window.isKeyWindow
            else { return }

            let firstResponder = window.firstResponder
            guard
                firstResponder !== self.textField,
                firstResponder !== self.textField.currentEditor()
            else { return }

            window.makeFirstResponder(self.textField)
        }
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        requestInitialFocusIfNeeded()
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        requestInitialFocusIfNeeded()
    }
}

/// Receives the click that reactivates the app, instead of requiring a second
/// click before AppKit starts secure text editing again.
final class ReactivatingSecureTextField: NSSecureTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
