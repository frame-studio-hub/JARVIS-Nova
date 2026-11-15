import SwiftUI
import AppKit

struct DiagnosticTextView: NSViewRepresentable {
    let text: String
    let onAskJarvis: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAskJarvis: onAskJarvis)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = DiagnosticNSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textColor = NSColor(
            calibratedRed: 0.35,
            green: 0.92,
            blue: 1.0,
            alpha: 1.0
        )
        textView.font = NSFont.monospacedSystemFont(
            ofSize: 12,
            weight: .regular
        )
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.onAskJarvis = context.coordinator.onAskJarvis

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? DiagnosticNSTextView else {
            return
        }

        textView.onAskJarvis = context.coordinator.onAskJarvis

        guard textView.string != text else {
            return
        }

        let selectedRange = textView.selectedRange()
        let oldScrollPosition = scrollView.contentView.bounds.origin
        let wasAtBottom = scrollView.contentView.bounds.maxY >=
            (textView.bounds.height - 30)

        textView.string = text

        let safeLocation = min(selectedRange.location, (text as NSString).length)
        let safeLength = min(
            selectedRange.length,
            (text as NSString).length - safeLocation
        )

        textView.setSelectedRange(
            NSRange(location: safeLocation, length: safeLength)
        )

        if wasAtBottom && selectedRange.length == 0 {
            textView.scrollToEndOfDocument(nil)
        } else {
            scrollView.contentView.scroll(to: oldScrollPosition)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    final class Coordinator {
        var onAskJarvis: (String) -> Void

        init(onAskJarvis: @escaping (String) -> Void) {
            self.onAskJarvis = onAskJarvis
        }
    }
}

final class DiagnosticNSTextView: NSTextView {
    var onAskJarvis: ((String) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(
            title: "Спросить JARVIS",
            action: #selector(askJarvisSelectedText),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())

        let copy = NSMenuItem(
            title: "Копировать",
            action: #selector(copy(_:)),
            keyEquivalent: ""
        )
        copy.target = self
        menu.addItem(copy)

        return menu
    }

    @objc private func askJarvisSelectedText() {
        let range = selectedRange()
        let source = string as NSString

        guard range.length > 0,
              NSMaxRange(range) <= source.length else {
            onAskJarvis?("")
            return
        }

        onAskJarvis?(source.substring(with: range))
    }
}