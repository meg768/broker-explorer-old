import AppKit
import SwiftUI

// Use AppKit's straight field border consistently with the Topic and Message fields.
struct ConnectionTextField: NSViewRepresentable {
    @Binding var text: String
    let label: String
    var placeholder = ""
    var isSecure = false
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField = isSecure ? NSSecureTextField() : NSTextField()
        field.stringValue = text
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = false
        field.isBordered = true
        field.drawsBackground = true
        field.focusRingType = .exterior
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.placeholderString = placeholder
        field.setAccessibilityLabel(label)
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ConnectionTextField

        init(parent: ConnectionTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
    }
}
