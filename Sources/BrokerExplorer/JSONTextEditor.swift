import AppKit
import SwiftUI

struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    private static let baseTextColor = NSColor.labelColor

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = RoundedEditorScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.focusRingType = .exterior

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = Self.baseTextColor
        textView.insertionPointColor = Self.baseTextColor
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(preserveSelection: false)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.parentText = $text
        textView.textColor = Self.baseTextColor
        textView.insertionPointColor = Self.baseTextColor

        if textView.string != text {
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.isUpdating = false
            context.coordinator.applyHighlighting(preserveSelection: false)
        } else {
            context.coordinator.applyHighlighting(preserveSelection: true)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parentText: Binding<String>
        weak var textView: NSTextView?
        var isUpdating = false

        init(text: Binding<String>) {
            self.parentText = text
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView else {
                return
            }

            parentText.wrappedValue = textView.string
            applyHighlighting(preserveSelection: true)
        }

        func applyHighlighting(preserveSelection: Bool) {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            let selectedRanges = preserveSelection ? textView.selectedRanges : [NSValue(range: NSRange(location: 0, length: 0))]
            let string = textView.string
            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: JSONTextEditor.baseTextColor
            ], range: fullRange)

            guard isJSONObject(string) else {
                storage.endEditing()
                textView.selectedRanges = selectedRanges
                return
            }

            highlight(pattern: #""(?:\\.|[^"\\])*""#, color: surfaceColor(role: .value), in: storage, text: string)
            highlight(pattern: #""(?:\\.|[^"\\])*"\s*:"#, color: surfaceColor(role: .key), trimTrailingColon: true, in: storage, text: string)
            highlight(pattern: #"(?<![\w.])-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, color: syntaxColor(light: NSColor.systemOrange, dark: NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.26, alpha: 1)), in: storage, text: string)
            highlight(pattern: #"\b(?:true|false|null)\b"#, color: syntaxColor(light: NSColor.systemPurple, dark: NSColor(calibratedRed: 0.78, green: 0.62, blue: 1.00, alpha: 1)), in: storage, text: string)
            let punctuationColor = syntaxColor(
                light: NSColor(calibratedRed: 0.40, green: 0.43, blue: 0.48, alpha: 1),
                dark: NSColor(calibratedRed: 0.75, green: 0.79, blue: 0.77, alpha: 1)
            )
            highlight(pattern: #"[{}\[\],:]"#, color: punctuationColor, in: storage, text: string)

            storage.endEditing()
            textView.selectedRanges = selectedRanges
        }

        private func isJSONObject(_ text: String) -> Bool {
            guard
                let data = text.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data)
            else {
                return false
            }

            return JSONSerialization.isValidJSONObject(object)
        }

        private func highlight(
            pattern: String,
            color: NSColor,
            trimTrailingColon: Bool = false,
            in storage: NSTextStorage,
            text: String
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return
            }

            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard var range = match?.range else {
                    return
                }

                if trimTrailingColon {
                    let matchedText = nsText.substring(with: range)
                    if let colonIndex = matchedText.lastIndex(of: ":") {
                        let distance = matchedText.distance(from: matchedText.startIndex, to: colonIndex)
                        range.length = distance
                    }
                }

                storage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }

        private func syntaxColor(light: NSColor, dark: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        }

        private enum SurfaceColorRole {
            case key
            case value
        }

        private func surfaceColor(role: SurfaceColorRole) -> NSColor {
            let surface = SettingsStore.loadSurfaceTheme()

            return NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

                switch (surface, role, isDark) {
                case (.hard, .key, false):
                    return NSColor(calibratedRed: 0.13, green: 0.20, blue: 0.27, alpha: 1)
                case (.hard, .key, true):
                    return NSColor(calibratedRed: 0.85, green: 0.90, blue: 0.95, alpha: 1)
                case (.hard, .value, false):
                    return NSColor(calibratedRed: 0.18, green: 0.36, blue: 0.53, alpha: 1)
                case (.hard, .value, true):
                    return NSColor(calibratedRed: 0.57, green: 0.75, blue: 0.91, alpha: 1)
                case (.grass, .key, false):
                    return NSColor(calibratedRed: 0.08, green: 0.52, blue: 0.36, alpha: 1)
                case (.grass, .key, true):
                    return NSColor(calibratedRed: 0.46, green: 0.88, blue: 0.68, alpha: 1)
                case (.grass, .value, false):
                    return NSColor(calibratedRed: 0.02, green: 0.59, blue: 0.41, alpha: 1)
                case (.grass, .value, true):
                    return NSColor(calibratedRed: 0.36, green: 0.88, blue: 0.62, alpha: 1)
                case (.clay, .key, false):
                    return NSColor(calibratedRed: 0.44, green: 0.20, blue: 0.16, alpha: 1)
                case (.clay, .key, true):
                    return NSColor(calibratedRed: 0.99, green: 0.80, blue: 0.72, alpha: 1)
                case (.clay, .value, false):
                    return NSColor(calibratedRed: 0.70, green: 0.30, blue: 0.20, alpha: 1)
                case (.clay, .value, true):
                    return NSColor(calibratedRed: 0.94, green: 0.60, blue: 0.46, alpha: 1)
                }
            }
        }
    }
}

// NSTextView remains the editor; only its enclosing field frame is rounded.
// AppKit renders the focus ring from this mask using the system accent color.
private final class RoundedEditorScrollView: NSScrollView {
    private let fieldCornerRadius: CGFloat = 6

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: fieldCornerRadius, yRadius: fieldCornerRadius).fill()
    }

}
