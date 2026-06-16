import AppKit
import SwiftUI

struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
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
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.parentText = $text
        if textView.string != text {
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.isUpdating = false
            context.coordinator.applyHighlighting()
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
            applyHighlighting()
        }

        func applyHighlighting() {
            guard let textView, let storage = textView.textStorage else {
                return
            }

            let selectedRanges = textView.selectedRanges
            let string = textView.string
            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ], range: fullRange)

            guard isJSONObject(string) else {
                storage.endEditing()
                textView.selectedRanges = selectedRanges
                return
            }

            highlight(pattern: #""(?:\\.|[^"\\])*""#, color: NSColor.systemGreen, in: storage, text: string)
            highlight(pattern: #""(?:\\.|[^"\\])*"\s*:"#, color: NSColor.systemRed, trimTrailingColon: true, in: storage, text: string)
            highlight(pattern: #"(?<![\w.])-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, color: NSColor.systemOrange, in: storage, text: string)
            highlight(pattern: #"\b(?:true|false|null)\b"#, color: NSColor.systemPurple, in: storage, text: string)
            let punctuationColor = NSColor(calibratedRed: 0.40, green: 0.43, blue: 0.48, alpha: 1)
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
    }
}
