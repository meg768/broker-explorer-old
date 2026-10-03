import AppKit
import SwiftUI

// Keep native keyboard editing and focus indication at a stable control height.
struct TopicTextField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.cell = VerticallyCenteredTextFieldCell(textCell: text)
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.placeholderString = "home/topic"
        field.focusRingType = .exterior
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        // Apply the proposed height to the native control itself, rather than
        // letting its intrinsic height leave empty space inside SwiftUI's frame.
        CGSize(
            width: proposal.width ?? nsView.intrinsicContentSize.width,
            height: proposal.height ?? nsView.intrinsicContentSize.height
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    private var isConfiguringEditor = false

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        // select/edit already receive the centered rectangle. AppKit asks for
        // drawingRect again while installing its field editor; do not inset or
        // center that rectangle a second time.
        if isConfiguringEditor { return rect }
        var contentRect = super.drawingRect(forBounds: rect)
        let textHeight = ceil(NSLayoutManager().defaultLineHeight(for: font ?? .systemFont(ofSize: NSFont.systemFontSize)))
        if contentRect.height > textHeight {
            contentRect.origin.y += (contentRect.height - textHeight) / 2
            contentRect.size.height = textHeight
        }
        return contentRect
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let textRect = drawingRect(forBounds: rect)
        isConfiguringEditor = true
        defer { isConfiguringEditor = false }
        super.select(withFrame: textRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let textRect = drawingRect(forBounds: rect)
        isConfiguringEditor = true
        defer { isConfiguringEditor = false }
        super.edit(withFrame: textRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }
}
