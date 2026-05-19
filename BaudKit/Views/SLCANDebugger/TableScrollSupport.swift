import SwiftUI
import AppKit

enum TableScrollEdge: Sendable {
    case top
    case bottom
}

@MainActor
final class TableScrollProxy {
    weak var tableView: NSTableView?
    private var hasPendingScroll = false

    func scheduleScroll(to edge: TableScrollEdge) {
        guard !hasPendingScroll else { return }
        hasPendingScroll = true
        DispatchQueue.main.async { [weak self] in
            self?.hasPendingScroll = false
            self?.scroll(to: edge)
        }
    }

    private func scroll(to edge: TableScrollEdge) {
        guard let tableView, tableView.numberOfRows > 0 else { return }
        tableView.layoutSubtreeIfNeeded()
        tableView.enclosingScrollView?.layoutSubtreeIfNeeded()

        let row: Int
        switch edge {
        case .top:
            row = 0
        case .bottom:
            row = tableView.numberOfRows - 1
        }

        guard !tableView.rows(in: tableView.visibleRect).contains(row) else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            tableView.scrollRowToVisible(row)
        }
    }
}

struct TableScrollReader: NSViewRepresentable {
    @Binding var proxy: TableScrollProxy?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            updateProxy(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            updateProxy(from: nsView)
        }
    }

    @MainActor
    private func updateProxy(from view: NSView) {
        guard let tableView = view.containingTableView else { return }
        if proxy?.tableView !== tableView {
            let p = proxy ?? TableScrollProxy()
            p.tableView = tableView
            proxy = p
        }
    }
}

@MainActor
private extension NSView {
    var containingTableView: NSTableView? {
        guard let contentView = window?.contentView else {
            return nil
        }

        let center = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
        return contentView
            .descendantTableViews(containingWindowPoint: center)
            .min { lhs, rhs in
                lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
            }
    }

    private func descendantTableViews(containingWindowPoint point: NSPoint) -> [NSTableView] {
        var matches: [NSTableView] = []

        for subview in subviews {
            if let tableView = subview as? NSTableView {
                let frameInWindow = tableView.convert(tableView.bounds, to: nil)
                if frameInWindow.contains(point) {
                    matches.append(tableView)
                }
            }
            matches.append(contentsOf: subview.descendantTableViews(containingWindowPoint: point))
        }

        return matches
    }
}
