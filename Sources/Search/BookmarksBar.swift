import SwiftUI

// The bookmarks bar: the top of the bookmarks, in a thin row above the page,
// as Chrome and Safari have one. A folder opens as a menu. More than the row
// holds scrolls sideways.
//
// Off unless asked for — Settings › Tabs, or Bookmarks › Show Bookmarks Bar
// — since the page gives up a strip of its height to it. It goes with the
// tabs when they fold away (⌘S) and when a video takes the screen.

struct BookmarksBar: View {
    @ObservedObject var browser: Browser
    let bookmarks: Bookmarks
    /// On the window's ground, above the page's card, with the tabs down the
    /// side: the ground's colour and no line of its own, the card's edge
    /// being the line (see CardEdge).
    var onFrame = false

    static let height: CGFloat = 30

    var body: some View {
        let _ = Bench.count("bar")
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(bookmarks.roots) { node in
                    Item(node: node) {
                        if node.isFolder {
                            BookmarkMenu.shared.popUp(node)
                        } else if let text = node.url, let url = URL(string: text) {
                            browser.openBookmark(url)
                        }
                    }
                    .overlay {
                        if let url = node.url.flatMap(URL.init(string:)) {
                            MiddleClick { browser.pickBookmark(url, inNewTab: true) }
                        }
                    }
                    .contextMenu {
                        if node.isFolder {
                            folderMenu(node)
                        } else if let url = node.url.flatMap(URL.init(string:)) {
                            bookmarkMenu(node, url)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: BookmarksBar.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button { bookmarks.askNewFolder(in: nil) } label: { Text("ui.new_folder", bundle: Language.resources) }
            Divider()
            Button { browser.bookmarking = true } label: { Text("ui.show_bookmarks", bundle: Language.resources) }
            Button {
                withAnimation(Motion.glide) { browser.prefs.bookmarksBar = false }
            } label: { Text("ui.hide_bookmarks_bar", bundle: Language.resources) }
        }
        .background {
            ZStack {
                // On glass the window's ground, colour and all, shows
                // through (Glass.swift).
                if !browser.glassy { onFrame ? Palette.frame : Palette.ground }
                // The tabs' wash carried on under them, or the colour
                // stopped at the bar's edge.
                if !browser.glassy { SpaceWash(look: browser.wash) }
            }
        }
        .overlay(alignment: .bottom) {
            if !onFrame { Rectangle().fill(Palette.hairline).frame(height: 1) }
        }
    }

    @ViewBuilder
    private func bookmarkMenu(_ node: Bookmark, _ url: URL) -> some View {
        Button { browser.pickBookmark(url, inNewTab: true) } label: { Text("ui.open_in_new_tab", bundle: Language.resources) }
        Button { browser.openInNewWindow([url]) } label: { Text("ui.open_in_new_window", bundle: Language.resources) }
        if browser.prefs.splitView {
            Button { browser.openInSplit(url) } label: { Text("ui.open_in_split_view", bundle: Language.resources) }
        }
        Button { browser.openShy(url) } label: { Text("ui.open_in_private_tab", bundle: Language.resources) }
        Divider()
        Button { bookmarks.askRename(node) } label: { Text("ui.rename", bundle: Language.resources) }
        Button { bookmarks.askAddress(node) } label: { Text("ui.edit_address", bundle: Language.resources) }
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        } label: { Text("ui.copy_link", bundle: Language.resources) }
        Divider()
        moveMenu(node)
        Button(role: .destructive) { bookmarks.askRemove(node) } label: { Text("Remove", bundle: Language.resources) }
    }

    @ViewBuilder
    private func folderMenu(_ node: Bookmark) -> some View {
        let urls = (node.children ?? []).compactMap { $0.url.flatMap(URL.init(string:)) }
        Button {
            for url in urls { browser.open(url, foreground: false, atEnd: true, from: browser.active, mayWait: true) }
        } label: { Text("ui.open_all_in_new_tabs", bundle: Language.resources) }
        .disabled(urls.isEmpty)
        Button { browser.openInNewWindow(urls) } label: { Text("ui.open_all_in_new_window", bundle: Language.resources) }
            .disabled(urls.isEmpty)
        if browser.prefs.usesTabGroups {
            Button { browser.openInTabGroup(urls, named: node.title) } label: { Text("ui.open_all_in_tab_group", bundle: Language.resources) }
                .disabled(urls.isEmpty)
        }
        Divider()
        Button { bookmarks.askRename(node) } label: { Text("ui.rename", bundle: Language.resources) }
        Button { bookmarks.askNewFolder(in: node.id) } label: { Text("ui.new_folder_inside", bundle: Language.resources) }
        Divider()
        moveMenu(node)
        Button(role: .destructive) { bookmarks.askRemove(node) } label: { Text("Remove", bundle: Language.resources) }
    }

    @ViewBuilder
    private func moveMenu(_ node: Bookmark) -> some View {
        let targets = Bookmarks.folders(bookmarks.roots).filter { !Bookmarks.holds($0.node.id, node) }
        if !targets.isEmpty {
            Menu {
                ForEach(targets, id: \.node.id) { target in
                    Button(String(repeating: "   ", count: target.depth) + target.node.title) {
                        bookmarks.move(node.id, into: target.node.id)
                    }
                }
            } label: { Text("ui.move_to", bundle: Language.resources) }
        }
    }

    /// One on the bar. A bookmark without a name is its icon alone, in a
    /// square as tall as the others, its address on hover.
    struct Item: View {
        let node: Bookmark
        let act: () -> Void
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 6) {
                if node.isFolder {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.muted)
                } else {
                    Mark(icon: Favicons.shared.cached(for: node.address), letter: String((node.host ?? "•").prefix(1)).uppercased(), size: 13)
                }
                if !node.unnamed {
                    Text(node.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                if node.isFolder {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                }
            }
            .padding(.horizontal, node.unnamed ? 0 : 8)
            .frame(minWidth: node.unnamed ? 22 : nil)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? Palette.hover : .clear))
            .contentShape(Rectangle())
            .onTapGesture(perform: act)
            .onHover { hovering = $0 }
            .help(node.url ?? node.title)
        }
    }
}
