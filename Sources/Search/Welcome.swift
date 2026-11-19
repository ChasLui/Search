import SwiftUI

/// The first time. Four short pages over the window, in the app's own
/// language: what this is, what to bring over, how to hold it, and whether
/// links from other apps should come here. Nothing is asked twice, and every
/// page can be skipped.
struct WelcomePanel: View {
    @ObservedObject private var language = Language.shared
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    @State private var page = 0
    @State private var forward = true

    // Bringing things over. Nil until one is picked, which means the first:
    // finding them looks through each browser's folders, and as an initial
    // value that ran every time the panel was made, the first window's
    // included, for a page that isn't showing yet.
    @State private var source: ImportSource?
    @State private var wantsPasswords = true
    @State private var wantsHistory = true
    @State private var wantsBookmarks = true
    @State private var bringing = false
    @State private var brought: [BringResult]?

    // The default browser.
    @State private var isDefault = Links.isDefault
    @State private var asked = false

    private var importsPasswords: Bool { (source ?? ImportSource.installed().first)?.importsPasswords ?? false }

    private let pages = 4

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    switch page {
                    case 0: welcome
                    case 1: bring
                    case 2: hold
                    default: links
                    }
                }
                .frame(maxWidth: 520)
                .id(page)
                .transition(.asymmetric(
                    insertion: .offset(x: forward ? 40 : -40).combined(with: .opacity),
                    removal: .offset(x: forward ? -40 : 40).combined(with: .opacity)
                ))
                Spacer(minLength: 0)
                foot
            }
            .padding(40)
        }
        .animation(Motion.glide, value: page)
        .transition(.opacity)
    }

    // MARK: - the pages

    private var welcome: some View {
        VStack(spacing: 22) {
            Plate(size: 72)
            VStack(spacing: 10) {
                Text("ui.search", bundle: Language.resources)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("ui.a_browser_with_nothing_in_the_way_four_megabytes_the_en", bundle: Language.resources)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 400)
            }
        }
    }

    private var bring: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("welcome.bring.title", "welcome.bring.detail")

            let sources = ImportSource.installed()
            let unreadable = Chromium.unreadable()
            if sources.isEmpty {
                if unreadable.isEmpty {
                    Text("ui.no_other_browser_found_on_this_mac_nothing_to_bring", bundle: Language.resources)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if sources.count > 1 {
                        Segmented(
                            options: sources.map { ($0, $0.name) },
                            selection: Binding(get: { source ?? sources[0] }, set: { source = $0 })
                        )
                    } else {
                        Text(Language.shared.format("welcome.from", fallback: "From %1$@", sources[0].name))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                    if importsPasswords {
                        Choice("welcome.passwords", "welcome.passwords.detail", on: $wantsPasswords)
                    } else {
                        Text(Language.shared.format("welcome.passwords.unsupported", fallback: "Passwords from %1$@ aren't supported yet.", (source ?? sources[0]).name))
                            .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    Choice("welcome.bookmarks", "welcome.bookmarks.detail", on: $wantsBookmarks)
                    Choice("welcome.history", "welcome.history.detail", on: $wantsHistory)
                }

                HStack(spacing: 12) {
                    Big(bringing ? "Bringing…" : "Bring them in", filled: true) { bringAll() }
                        .disabled(bringing || brought != nil || !((importsPasswords && wantsPasswords) || wantsHistory || wantsBookmarks))
                    if bringing { Ring(size: 10) }
                    if let brought {
                        Text(brought.map(\.text).joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .transition(.opacity)
                    }
                }
                .animation(Motion.settle, value: brought)
            }

            if !unreadable.isEmpty {
                Text(unreadable.map(\.localizedMessage).joined(separator: "\n"))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Safari, a browser on another Mac, one Search can't read: what
            // it exported, bookmarks, passwords or Safari's own ZIP.
            Pill("ui.from_a_file_another_browser_exported") { browser.importFile() }
        }
    }

    private var hold: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("welcome.layout.title", "welcome.layout.detail")
            HStack(spacing: 12) {
                Way(title: "welcome.layout.sidebar", sidebar: true, chosen: prefs.sidebar) {
                    withAnimation(Motion.glide) { prefs.sidebar = true }
                }
                Way(title: "welcome.layout.tabs", sidebar: false, chosen: !prefs.sidebar) {
                    withAnimation(Motion.glide) { prefs.sidebar = false }
                }
            }
            HStack(spacing: 12) {
                Text("ui.tabs_wear", bundle: Language.resources)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                Segmented(options: Glyph.allCases.map { ($0, $0.title) }, selection: $prefs.glyph, localized: true)
            }
        }
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("welcome.links.title", "welcome.links.detail")
            HStack(spacing: 12) {
                if isDefault {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                        Text("ui.search_is_the_default_browser", bundle: Language.resources)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                } else {
                    Big("Make Search the default", filled: true) {
                        asked = true
                        Links.becomeDefault { _ in isDefault = Links.isDefault }
                    }
                    if asked, !isDefault {
                        Text("ui.macos_asks_in_its_own_dialog", bundle: Language.resources)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.faint)
                    }
                }
            }
            .animation(Motion.settle, value: isDefault)

            VStack(alignment: .leading, spacing: 8) {
                Text("ui.a_few_things_worth_knowing", bundle: Language.resources)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.faint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.top, 6)
                Key("⌘T", "welcome.key.new_tab")
                Key("⌘K", "welcome.key.tabs")
                Key("⌘,", "welcome.key.settings")
                Key("⌃1", "welcome.key.spaces")
                Key("⌥⌘N", "welcome.key.split")
                Key("⌘O", "welcome.key.links")
                Key("⌘L", "welcome.key.suggestions")
                Key("⌘", "welcome.key.numbers")
                Key("⌘1", "welcome.key.pin")
                Key("⇧⌘P", "welcome.key.video")
                Key("⌃-click", "welcome.key.side_panel")
                Key("⌘Q", "welcome.key.quit")
                Key("⌘,", "welcome.key.passwords")
                if PageTranslator.available {
                    Key("⌃-click", "welcome.key.translate")
                }
                if AI.shipped {
                    Key("⌘,", "welcome.key.ai")
                }
            }
        }
    }

    // MARK: - the bottom edge

    private var foot: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<pages, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Palette.ink : Palette.faint.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if page > 0 {
                Button { forward = false; page -= 1 } label: { Text("ui.back", bundle: Language.resources) }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            if page < pages - 1 {
                Button { finish() } label: { Text("ui.skip", bundle: Language.resources) }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            Big(page < pages - 1 ? "Continue" : "Start browsing", filled: true) {
                if page < pages - 1 { forward = true; page += 1 } else { finish() }
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: 520)
    }

    // MARK: - doing

    private enum BringResult: Equatable {
        case passwords(Int, undecrypted: Int)
        case noPassphrase
        case primaryPassword(String)
        case unreadable
        case bookmarks(Int)
        case places(Int)

        @MainActor var text: String {
            let language = Language.shared
            switch self {
            case let .passwords(count, undecrypted):
                let passwords = language.count("count.passwords", count)
                guard undecrypted > 0 else { return passwords }
                return language.format("welcome.result.passwords", fallback: "%1$@ (%2$@)",
                                       passwords, language.count("count.undecrypted", undecrypted))
            case .noPassphrase:
                return language.text("welcome.result.no_key", fallback: "passwords: macOS didn't hand over the key — allow it and try again")
            case .primaryPassword(let source):
                return language.format("welcome.result.primary_password", fallback: "passwords: %1$@ has a primary password — export them from it and bring in the CSV", source)
            case .unreadable:
                return language.text("welcome.result.unreadable", fallback: "passwords: nothing readable")
            case .bookmarks(let count):
                return language.count("count.bookmarks", count)
            case .places(let count):
                return language.count("count.places", count)
            }
        }
    }

    private func bringAll() {
        guard let source = source ?? ImportSource.installed().first else { return }
        // The profile used most recently, without asking: the sheet in
        // Settings › Passwords is where another is chosen.
        let profile = source.usual
        bringing = true
        var lines: [BringResult] = []
        let group = DispatchGroup()
        if wantsPasswords && source.importsPasswords {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let outcome = Result { try source.read(profile: profile) }
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let found):
                        let kept = browser.keep(found)
                        ImportRecords.note(source.name, passwords: kept)
                        lines.append(.passwords(kept, undecrypted: found.undecrypted))
                    case .failure(Chromium.Trouble.noPassphrase):
                        lines.append(.noPassphrase)
                    case .failure(Mozilla.Trouble.primaryPassword):
                        lines.append(.primaryPassword(source.name))
                    case .failure:
                        lines.append(.unreadable)
                    }
                    group.leave()
                }
            }
        }
        if wantsBookmarks {
            lines.append(.bookmarks(browser.takeBookmarks(from: source, profile: profile).added))
        }
        if wantsHistory {
            group.enter()
            browser.takePlaces(from: source, profile: profile) { count in
                lines.append(.places(count))
                group.leave()
            }
        }
        group.notify(queue: .main) {
            bringing = false
            brought = lines
            browser.relist()
        }
    }

    private func finish() {
        prefs.welcomed = true
        withAnimation(Motion.settle) { browser.welcoming = false }
    }

    private func heading(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title), bundle: Language.resources)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.ink)
            Text(LocalizedStringKey(line), bundle: Language.resources)
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - pieces

    /// The mark alone, at whatever height the page wants — no plate behind
    /// it, the same as everywhere else it's drawn.
    private struct Plate: View {
        let size: CGFloat
        var body: some View {
            Logomark()
                .fill(Palette.ink, style: FillStyle(eoFill: true))
                .aspectRatio(Logomark.canvas.width / Logomark.canvas.height, contentMode: .fit)
                .frame(height: size * 0.56)
        }
    }

    private struct Big: View {
        let title: String
        var filled = false
        let act: () -> Void
        @State private var hovering = false

        init(_ title: String, filled: Bool = false, act: @escaping () -> Void) {
            self.title = title
            self.filled = filled
            self.act = act
        }

        var body: some View {
            Button(action: act) {
                Text(LocalizedStringKey(title), bundle: Language.resources)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(filled ? Palette.ground : Palette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(filled ? Palette.ink : (hovering ? Palette.hover : Palette.wash), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }

    private struct Choice: View {
        let title: String
        let detail: String
        @Binding var on: Bool

        init(_ title: String, _ detail: String, on: Binding<Bool>) {
            self.title = title
            self.detail = detail
            _on = on
        }

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title), bundle: Language.resources).font(.system(size: 13.5)).foregroundStyle(Palette.ink)
                    Text(LocalizedStringKey(detail), bundle: Language.resources).font(.system(size: 11.5)).foregroundStyle(Palette.faint)
                }
                Spacer()
                Switch(on: $on)
            }
        }
    }

    /// One of the two ways, as a small drawing of the window.
    private struct Way: View {
        let title: String
        let sidebar: Bool
        let chosen: Bool
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: pick) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.ground)
                        if sidebar {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Palette.faint).frame(width: 5, height: 5) } }
                                        .padding(.bottom, 4)
                                    ForEach(0..<4, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Palette.wash : Palette.hover).frame(height: 8)
                                    }
                                }
                                .padding(8)
                                .frame(width: 62)
                                Rectangle().fill(Palette.hairline).frame(width: 1)
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 3) {
                                HStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Palette.faint).frame(width: 5, height: 5) } }
                                    .padding(.trailing, 6)
                                ForEach(0..<4, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Palette.wash : Palette.hover).frame(width: 30, height: 8)
                                }
                            }
                            .padding(8)
                        }
                    }
                    .frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                    Text(LocalizedStringKey(title), bundle: Language.resources)
                        .font(.system(size: 13, weight: chosen ? .medium : .regular))
                        .foregroundStyle(chosen ? Palette.ink : Palette.muted)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(chosen ? Palette.wash : (hovering ? Palette.hover : .clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(chosen ? Palette.ink.opacity(0.35) : Palette.hairline, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
            .animation(Motion.settle, value: chosen)
        }
    }

    private struct Key: View {
        let keys: String
        let what: String
        init(_ keys: String, _ what: String) { self.keys = keys; self.what = what }
        var body: some View {
            HStack(spacing: 10) {
                Text(keys)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .frame(minWidth: 44)
                Text(LocalizedStringKey(what), bundle: Language.resources).font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
        }
    }
}
