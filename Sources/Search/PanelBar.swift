import AppKit
import SwiftTerm
import SwiftUI

// The panel bar down the window's far edge, as Vivaldi has one: Bookmarks,
// Downloads, History, a terminal and the web panel, each opening the side
// panel on itself, and pressed again closing it. ⌥⌘P shows and hides the bar
// with its panel, bringing back what was open last; ⌥⌘J, ⌥⌘H and ⌥⌘T open it
// on Downloads, History and the terminal.

extension Browser {
    /// The side panel on `content`, the bar out with it; the same again, and
    /// the panel goes, and the bar with it, if it came out only for this.
    func togglePanel(_ content: SidePanelContent) {
        guard !isPopup else { return }
        if sidePanelShown, sidePanel == content { return closeBarPanel() }
        borrowBar()
        if case .page(_, _, let tab?) = sidePanel { SidePanelPages.shared.unbind(tab, in: self) }
        SidePanelPages.shared.drop(in: self)
        sidePanel = content
        sidePanelShown = true
        if let key = content.barKey { prefs.panelLast = key }
    }

    /// The web panel from the bar: the site last there, or the first offered.
    func toggleBarSite() {
        guard !isPopup else { return }
        if sidePanelShown, case .site = sidePanel { return closeBarPanel() }
        borrowBar()
        let last = URL(string: prefs.panelSite).flatMap { PanelSites.allowed($0) ? $0 : nil }
        if showSiteInPanel(last ?? PanelSites.offered[0].url) { prefs.panelLast = "site" }
    }

    /// The bar out for a panel: kept in mind if it was hidden, to hide it
    /// again when that panel closes.
    private func borrowBar() {
        guard !prefs.panelBar else { return }
        prefs.panelBar = true
        prefs.panelBarBorrowed = true
    }

    /// A panel of the bar's closed, by its key again or its cross: the bar
    /// goes back to how it was before.
    func closeBarPanel() {
        closeSidePanel()
        if prefs.panelBarBorrowed, prefs.panelBarRestores { prefs.panelBar = false }
        prefs.panelBarBorrowed = false
    }

    /// ⌥⌘P: the bar alone, shown or hidden; hidden, any panel goes with it.
    func togglePanelBar() {
        prefs.panelBarBorrowed = false
        if prefs.panelBar {
            if sidePanelShown { closeSidePanel() }
            prefs.panelBar = false
        } else {
            prefs.panelBar = true
        }
    }
}

extension SidePanelContent {
    /// What the bar remembers it by, for ⌥⌘P; nil for an extension's page.
    var barKey: String? {
        switch self {
        case .bookmarks: return "bookmarks"
        case .downloads: return "downloads"
        case .history: return "history"
        case .terminal: return "terminal"
        case .site: return "site"
        case .page: return nil
        }
    }
}

/// The bar itself: a narrow column of doors at the window's far edge.
struct PanelBar: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    static let width: CGFloat = 40

    var body: some View {
        VStack(spacing: 4) {
            Door(icon: "bookmark", on: shown(.bookmarks), help: "Bookmarks") { browser.togglePanel(.bookmarks) }
            Door(icon: "arrow.down.circle", on: shown(.downloads), help: "Downloads",
                 shortcut: "history.downloads") { browser.togglePanel(.downloads) }
            Door(icon: "clock", on: shown(.history), help: "History",
                 shortcut: "history.show") { browser.togglePanel(.history) }
            Door(icon: "terminal", on: shown(.terminal), help: "Terminal",
                 shortcut: "view.terminal") { browser.togglePanel(.terminal) }
            if prefs.sitesInPanel {
                Rectangle().fill(Palette.hairline).frame(width: 18, height: 1).padding(.vertical, 4)
                Door(icon: "globe", on: siteShown, help: siteName) { browser.toggleBarSite() }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .frame(width: PanelBar.width)
        .frame(maxHeight: .infinity)
        .background(Palette.ground)
        .overlay(alignment: .leading) { Rectangle().fill(Palette.hairline).frame(width: 1) }
    }

    private func shown(_ content: SidePanelContent) -> Bool {
        browser.sidePanelShown && browser.sidePanel == content
    }

    private var siteShown: Bool {
        guard browser.sidePanelShown, case .site = browser.sidePanel else { return false }
        return true
    }

    private var siteName: String {
        URL(string: prefs.panelSite)?.host().map(Address.withoutWWW) ?? "Website"
    }
}

/// The title line every panel of the bar starts with.
private struct PanelHead: View {
    let title: String
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Door(icon: "xmark", help: "Close", act: close)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
    }
}

/// A search field for a panel's list.
private struct PanelHunt: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.hover))
        .padding(10)
    }
}

/// One line of a panel's list: a mark, a title, a line under it.
private struct PanelRow: View {
    let mark: AnyView
    let title: String
    var detail: String? = nil
    var trailing: String? = nil
    var depth = 0
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            mark.frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .monospacedDigit()
            }
        }
        .padding(.leading, 10 + CGFloat(depth) * 14)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? Palette.hover : .clear))
        .contentShape(Rectangle())
        .onTapGesture(perform: act)
        .onHover { hovering = $0 }
        .padding(.horizontal, 6)
    }
}

// MARK: - history

struct HistorySide: View {
    @ObservedObject var browser: Browser
    @State private var hunt = ""
    @State private var lines: [Line] = []

    struct Line: Identifiable {
        let id: String
        let day: String?
        let trace: History.Trace?
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHead(title: "History") { browser.closeBarPanel() }
            PanelHunt(text: $hunt, prompt: "Search history")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        if let day = line.day {
                            Text(day)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.muted)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                        } else if let trace = line.trace {
                            PanelRow(
                                mark: AnyView(Mark(icon: Favicons.shared.cached(for: trace.url),
                                                   letter: trace.address.first.map { String($0).uppercased() } ?? "•")),
                                title: trace.title.isEmpty ? Address.withoutWWW(trace.address) : trace.title,
                                detail: Address.withoutWWW(trace.address),
                                trailing: When.clock(trace.last)
                            ) {
                                if NSEvent.modifierFlags.contains(.command) {
                                    browser.open(trace.url, foreground: false)
                                } else {
                                    browser.active?.go(to: trace.url)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear(perform: refresh)
        .onChange(of: hunt) { _, _ in refresh() }
        .onChange(of: browser.spaceID) { _, _ in refresh() }
    }

    private func refresh() {
        let traces = browser.history.everything(matching: hunt)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: traces) { calendar.startOfDay(for: $0.last) }
        var made: [Line] = []
        for day in grouped.keys.sorted(by: >) {
            made.append(Line(id: "day " + day.description, day: When.day(day), trace: nil))
            for trace in grouped[day]!.sorted(by: { $0.last > $1.last }) {
                made.append(Line(id: trace.id, day: nil, trace: trace))
            }
        }
        lines = made
    }
}

// MARK: - bookmarks

struct BookmarksSide: View {
    @ObservedObject var browser: Browser
    @State private var hunt = ""
    @State private var open: Set<Bookmark.ID> = []

    private struct Line: Identifiable {
        let node: Bookmark
        let depth: Int
        var id: Bookmark.ID { node.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHead(title: "Bookmarks") { browser.closeBarPanel() }
            PanelHunt(text: $hunt, prompt: "Search bookmarks")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        let node = line.node
                        if node.isFolder {
                            PanelRow(
                                mark: AnyView(Image(systemName: open.contains(node.id) ? "folder.fill" : "folder")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.muted)),
                                title: node.label,
                                depth: line.depth
                            ) {
                                if open.contains(node.id) { open.remove(node.id) } else { open.insert(node.id) }
                            }
                        } else if let text = node.url, let url = URL(string: text) {
                            PanelRow(
                                mark: AnyView(Mark(icon: Favicons.shared.cached(for: url),
                                                   letter: node.label.first.map { String($0).uppercased() } ?? "•")),
                                title: node.label,
                                depth: line.depth
                            ) {
                                browser.openBookmark(url)
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The tree as drawn: open folders' contents under them; with a search,
    /// every bookmark that matches, flat.
    private var lines: [Line] {
        let roots = browser.bookmarks.roots
        let typed = hunt.trimmingCharacters(in: .whitespaces).lowercased()
        var made: [Line] = []
        if !typed.isEmpty {
            func find(_ nodes: [Bookmark]) {
                for node in nodes {
                    if node.isFolder { find(node.children ?? []) }
                    else if node.label.lowercased().contains(typed) || (node.url ?? "").lowercased().contains(typed) {
                        made.append(Line(node: node, depth: 0))
                    }
                }
            }
            find(roots)
            return made
        }
        func walk(_ nodes: [Bookmark], depth: Int) {
            for node in nodes {
                made.append(Line(node: node, depth: depth))
                if node.isFolder, open.contains(node.id) { walk(node.children ?? [], depth: depth + 1) }
            }
        }
        walk(roots, depth: 0)
        return made
    }
}

// MARK: - terminal

/// A shell in the panel: zsh, logged in, in your home folder. Kept for the
/// window while it is open, so closing the panel and opening it again finds
/// the same shell where it was; a shell that exits is started afresh.
struct TerminalSide: View {
    @ObservedObject var browser: Browser

    var body: some View {
        VStack(spacing: 0) {
            PanelHead(title: "Terminal") { browser.closeBarPanel() }
            ShellView(owner: ObjectIdentifier(browser))
                .padding(.leading, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: Shells.ground))
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

@MainActor
enum Shells {
    static let ground = NSColor(calibratedWhite: 0.09, alpha: 1)
    private static var kept: [ObjectIdentifier: LocalProcessTerminalView] = [:]
    private static var watchers: [ObjectIdentifier: Watcher] = [:]

    static func shell(for owner: ObjectIdentifier) -> LocalProcessTerminalView {
        if let view = kept[owner], view.process.running { return view }
        let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.nativeBackgroundColor = ground
        view.nativeForegroundColor = NSColor(calibratedWhite: 0.9, alpha: 1)
        let watcher = Watcher()
        view.processDelegate = watcher
        watchers[owner] = watcher
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        if let path = ProcessInfo.processInfo.environment["PATH"] { env.append("PATH=\(path)") }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let name = "-" + (shell as NSString).lastPathComponent
        view.startProcess(executable: shell, args: [], environment: env, execName: name,
                          currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path)
        kept[owner] = view
        return view
    }

    final class Watcher: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}

private struct ShellView: NSViewRepresentable {
    let owner: ObjectIdentifier

    func makeNSView(context: Context) -> NSView {
        let holder = NSView()
        place(in: holder)
        return holder
    }

    func updateNSView(_ holder: NSView, context: Context) { place(in: holder) }

    private func place(in holder: NSView) {
        let shell = Shells.shell(for: owner)
        if shell.superview !== holder {
            holder.subviews.forEach { $0.removeFromSuperview() }
            shell.removeFromSuperview()
            shell.frame = holder.bounds
            shell.autoresizingMask = [.width, .height]
            holder.addSubview(shell)
        }
        // Typing goes to the shell as soon as it shows.
        DispatchQueue.main.async { shell.window?.makeFirstResponder(shell) }
    }
}
