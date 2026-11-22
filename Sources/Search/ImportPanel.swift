import SwiftUI

/// Bringing things over from another browser, all in one place: which
/// browser, which of its profiles, and what of it. Opened from Settings ›
/// Passwords and from Bring in… in Bookmarks and Passwords; the Welcome has
/// the short version of it. From Settings › Extensions it opens on the
/// extensions alone.
///
/// What each browser holds is counted as the sheet opens, off the main
/// thread and from its files alone — no key is asked for and nothing is
/// decrypted, so nothing prompts until Bring them in is pressed. Then macOS
/// asks once for that browser's key, if it keeps one.
struct ImportPanel: View {
    @ObservedObject private var language = Language.shared
    @ObservedObject var browser: Browser

    @State private var sources: [ImportSource] = []
    @State private var unreadable: [Chromium.Unavailable] = []
    @State private var folderError: URL?
    @State private var looking = true
    @State private var pick: ImportSource?
    /// Each browser's profiles, and the one used most recently.
    @State private var profiles: [String: [ImportSource.Profile]] = [:]
    @State private var usual: [String: String] = [:]
    /// The profile chosen for a browser, where it isn't the usual one:
    /// a folder's name, or "" for all of them.
    @State private var chosen: [String: String] = [:]
    @State private var previews: [String: ImportSource.Preview] = [:]

    @State private var wantsPasswords = true
    @State private var wantsBookmarks = true
    @State private var wantsHistory = true
    @State private var wantsExtensions = false
    /// A browser's open tabs and tab groups (see takeSession).
    /// Off unless asked for.
    @State private var wantsTabs = false
    /// What came from this browser before goes, and its bookmarks come
    /// fresh. Off unless asked for; passwords are never taken out.
    @State private var replaceBookmarks = false
    /// Arc's or Zen's spaces, their pinned tabs, and Arc's favourites or
    /// Zen's Essentials (see takeArc).
    @State private var wantsArc = true
    /// How many spaces and pinned things Arc or Zen has, by browser and profile.
    @State private var arcCounts: [String: (spaces: Int, pinned: Int)] = [:]
    /// Opened for the extensions: the first browser counted with some is
    /// picked, until you pick one yourself.
    @State private var forExtensions = false
    @State private var bringing = false
    @State private var brought: [Said]?
    /// Whether that import left any bookmarks behind, which is what the
    /// offer to show the bar is for.
    @State private var marksLanded = false
    /// The steps for exporting from Safari, shown when asked.
    @State private var safariSteps = false

    enum Said: Hashable {
        case passwords(Int, skipped: Int, undecrypted: Int, source: String)
        case noKey(String), primaryPassword(String), noPasswords(String)
        case bookmarksKept(String, Int), noBookmarks(String), bookmarks(Int), bookmarksWithExisting(Int, Int)
        case places(Int), extensions(Int)
        case arcAlready(String), arc(Int, Int, Int)
        case sessionAlready(String), session(Int, Int, Int)

        var ok: Bool {
            switch self {
            case .passwords(let kept, _, let undecrypted, _): return kept > 0 || undecrypted == 0
            case .noKey, .primaryPassword, .noPasswords, .bookmarksKept: return false
            default: return true
            }
        }

        @MainActor var text: String {
            let language = Language.shared
            switch self {
            case let .passwords(count, skipped, undecrypted, source):
                let passwords = language.count("count.passwords", count)
                let skippedText = language.count("count.skipped_no_address", skipped)
                let lockedText = language.format("import.result.locked", fallback: "%1$@ with %2$@'s key", language.count("count.undecrypted", undecrypted), source)
                if skipped > 0 && undecrypted > 0 {
                    return language.format("import.result.passwords_both", fallback: "%1$@ (%2$@) — %3$@", passwords, skippedText, lockedText)
                }
                if skipped > 0 { return language.format("import.result.passwords_skipped", fallback: "%1$@ (%2$@)", passwords, skippedText) }
                if undecrypted > 0 { return language.format("import.result.passwords_locked", fallback: "%1$@ — %2$@", passwords, lockedText) }
                return passwords
            case .noKey(let source):
                return language.format("import.result.no_key", fallback: "macOS didn't hand over %1$@'s key — allow it and try again", source)
            case .primaryPassword(let source):
                return language.format("import.result.primary_password", fallback: "%1$@ has a primary password: export your passwords from it and bring in the CSV file", source)
            case .noPasswords(let source):
                return language.format("import.result.no_passwords", fallback: "No passwords readable in %1$@", source)
            case let .bookmarksKept(source, added):
                return language.format("import.result.bookmarks_kept", fallback: "Couldn't read all of %1$@'s bookmarks: what came from it before was kept, %2$@", source, language.count("count.new_bookmarks", added))
            case .noBookmarks(let source):
                return language.format("import.result.no_bookmarks", fallback: "No bookmarks in %1$@", source)
            case .bookmarks(let count): return language.count("count.bookmarks", count)
            case let .bookmarksWithExisting(added, already):
                return language.format("import.result.bookmarks_existing", fallback: "%1$@, %2$@", language.count("count.new_bookmarks", added), language.count("count.already_here", already))
            case .places(let count): return language.count("count.places", count)
            case .extensions(let count): return language.count("count.extensions_confirm", count)
            case .arcAlready(let source): return language.format("import.result.arc_already", fallback: "%1$@'s spaces and pins were all here already", source)
            case let .arc(spaces, pins, tabs):
                return language.format("import.result.arc", fallback: "%1$@, %2$@, %3$@", language.count("count.new_spaces", spaces), language.count("count.pins", pins), language.count("count.pinned_tabs", tabs))
            case .sessionAlready(let source):
                return language.format("import.result.session_already", fallback: "%1$@'s open tabs were all here already", source)
            case let .session(tabs, groups, pins):
                var parts = [language.count("count.open_tabs", tabs)]
                if groups > 0 { parts.append(language.count("count.new_groups", groups)) }
                if pins > 0 { parts.append(language.count("count.pins", pins)) }
                let list = ListFormatter()
                list.locale = language.locale
                return list.string(from: parts) ?? parts.joined(separator: ", ")
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ui.nothing_in_the_other_browser_changes_passwords_go_into_", bundle: Language.resources)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.muted)

            if looking {
                HStack(spacing: 8) {
                    Ring(size: 10)
                    Text("ui.looking_on_this_mac", bundle: Language.resources).font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            } else if sources.isEmpty {
                Card { Nothing(unreadable.isEmpty ? "No other browser found on this Mac." : "Choose a browser's data folder below to allow Search to read it.") }
            } else {
                Caption("ui.on_this_mac", localized: true)
                Card {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        if index > 0 { Rule() }
                        Row(name: source.name, detail: detail(of: source), can: source.localizedCanBringLine, chosen: pick == source) {
                            guard !bringing else { return }
                            pick = source
                            replaceBookmarks = false
                            forExtensions = false
                            brought = nil
                        }
                    }
                }
            }

            notes

            if let source = pick {
                options(for: source)
            }
        }
    }

    var body: some View {
        Plate("plate.import", localizedTitle: true, width: 580, close: { browser.bringingIn = nil }) {
            // As tall as it needs to be, and scrolling past what the window
            // can hold: many browsers, or a small window.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
                    .scrollBounceBehavior(.basedOnSize)
            }
        } foot: {
            VStack(alignment: .leading, spacing: 10) {
                if let brought {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(brought, id: \.self) { said in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: said.ok ? "checkmark" : "exclamationmark.circle")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(said.ok ? Palette.ink : Palette.muted)
                                    .frame(width: 12)
                                Text(said.text)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(said.ok ? Palette.ink : Palette.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .transition(.opacity)
                }
                HStack(spacing: 8) {
                    if brought != nil {
                        Pill("ui.show_bookmarks_60af0d") { browser.lead(to: InternalPage(.bookmarks)) }
                        // The bar is off until it is asked for, and nobody asks
                        // for a row that has nothing in it. Bookmarks having just
                        // arrived is the one moment it is worth offering; the
                        // bar comes in above this page, where it is seen.
                        if marksLanded, !browser.prefs.bookmarksBar {
                            Pill("ui.show_the_bookmarks_bar") {
                                withAnimation(Motion.glide) { browser.prefs.bookmarksBar = true }
                            }
                        }
                        Pill("ui.show_passwords") { browser.lead(to: InternalPage(.passwords)) }
                    } else if let source = pick {
                        Pill(bringing ? "Bringing…" : "Bring them in", filled: true) { bring(from: source) }
                            .disabled(bringing || !(wantsPasswords || wantsBookmarks || wantsHistory || (wantsExtensions && !fresh(source).isEmpty)
                                                     || (wantsArc && arcCounts[key(source, profile(of: source))] != nil)
                                                     || (wantsTabs && bringsTabs(source))))
                        if bringing { Ring(size: 10) }
                    }
                    Spacer(minLength: 8)
                    Pill("ui.file") { browser.importFile() }
                        .disabled(bringing)
                }
            }
        }
        .animation(Motion.settle, value: brought)
        .animation(Motion.settle, value: pick)
        .onAppear {
            if browser.bringingExtensions {
                browser.bringingExtensions = false
                forExtensions = true
                wantsExtensions = true
                wantsPasswords = false
                wantsBookmarks = false
                wantsHistory = false
            }
            look()
        }
        .onChange(of: previews) { _, _ in
            guard forExtensions, let pick, fresh(pick).isEmpty,
                  let other = sources.first(where: { !fresh($0).isEmpty }) else { return }
            self.pick = other
        }
        // Asked for again at another browser while still open.
        .onChange(of: browser.bringingIn) { _, name in
            guard !bringing, let found = sources.first(where: { $0.name == name }) else { return }
            pick = found
            brought = nil
        }
    }

    /// What Arc's side of the import will do, which depends on whether pinned
    /// rows are on: with them on, the pages Arc keeps loose become rows under
    /// the pins and the ones it filed stay tabs in a group of that folder's
    /// name, so that neither the keeping nor the folder is lost.
    private func arcDetail(_ arc: (spaces: Int, pinned: Int), _ source: ImportSource) -> String {
        let spaces = language.count("count.spaces", arc.spaces)
        let pinned = language.count("count.pinned", arc.pinned)
        let favourites = source.name == "Zen"
            ? language.text("import.favourites.essentials", fallback: "Essentials")
            : language.text("import.favourites", fallback: "favourites")
        if browser.prefs.listsPins && browser.prefs.pinFolders {
            return language.format("import.arc.folders", fallback: "%1$@, %2$@ — each a space here, the %3$@ as pins, its pinned pages as rows under them, in its folders as folders of rows", spaces, pinned, favourites)
        }
        return browser.prefs.listsPins
            ? language.format("import.arc.rows", fallback: "%1$@, %2$@ — each a space here, the %3$@ as pins, its pinned pages as rows under them, and the ones it filed in a folder as tabs in a group of that name", spaces, pinned, favourites)
            : language.format("import.arc.sleeping", fallback: "%1$@, %2$@ — each a space here, the %3$@ as pins, its pinned tabs asleep in it", spaces, pinned, favourites)
    }

    /// Whether Arc's own spaces are coming over: they hold its tabs, which
    /// its session file holds again, so its open tabs then stay behind.
    /// Zen's open tabs leave its pins out, so both can come.
    private func takesArc(_ source: ImportSource) -> Bool {
        wantsArc && source.sessionRepeatsSpaces && arcCounts[key(source, profile(of: source))] != nil
    }

    /// Whether the open tabs switch, on, would bring anything.
    private func bringsTabs(_ source: ImportSource) -> Bool {
        (previews[key(source, profile(of: source))]?.session.tabs ?? 0) > 0 && !takesArc(source)
    }

    /// What the open tabs side of the import will do.
    private func tabsDetail(_ preview: ImportSource.Preview?, _ source: ImportSource) -> String {
        guard let session = preview?.session, session.tabs > 0 else { return language.format("import.no_open_tabs", fallback: "None open in %1$@", source.name) }
        if takesArc(source) { return language.text("import.arc_tabs", fallback: "They come with Arc's spaces; turn those off to bring its open tabs instead") }
        let tabs = session.found > session.tabs
            ? language.format("import.first_tabs", fallback: "The first %1$@ of %2$@ tabs", session.tabs.formatted(), session.found.formatted())
            : language.count("count.tabs", session.tabs)
        var keepsSpaces = false
        if case .mozilla(let mozilla) = source { keepsSpaces = mozilla.keepsSpaces }
        if session.groups.isEmpty {
            return keepsSpaces
                ? language.format("import.tabs_spaces_detail", fallback: "%1$@ — asleep at the end of this space; its pinned tabs come with its spaces", tabs)
                : language.format("import.tabs_detail", fallback: "%1$@ — asleep at the end of this space, pinned tabs as pins", tabs)
        }
        return keepsSpaces
            ? language.format("import.tabs_spaces_groups_detail", fallback: "%1$@ in %2$@ — asleep at the end of this space; its pinned tabs come with its spaces", tabs, language.count("count.groups", session.groups.count))
            : language.format("import.tabs_groups_detail", fallback: "%1$@ in %2$@ — asleep at the end of this space, pinned tabs as pins", tabs, language.count("count.groups", session.groups.count))
    }

    /// Safari, and browsers on this Mac with nothing where their data should
    /// be: said by name rather than left out.
    @ViewBuilder
    private var notes: some View {
        if ImportSource.safari || !unreadable.isEmpty || folderError != nil {
            VStack(alignment: .leading, spacing: 4) {
                if ImportSource.safari {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(language.text("import.safari.files", fallback: "Safari — macOS keeps its files from other apps, so it comes over from a file it exports."))
                        Spacer(minLength: 4)
                        Pill(safariSteps ? "ui.hide" : "ui.how") { withAnimation(Motion.settle) { safariSteps.toggle() } }
                    }
                    if safariSteps {
                        Text(language.text("import.safari.steps", fallback: "In Safari, choose File › Export Browsing Data to File…, keep Bookmarks, History and Passwords, and save. Then press File… below and choose the ZIP it made."))
                            .foregroundStyle(Palette.muted)
                            .transition(.opacity)
                    }
                }
                ForEach(unreadable.indices, id: \.self) { index in
                    let missing = unreadable[index]
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(missing.localizedMessage)
                        Spacer(minLength: 4)
                        Pill("ui.choose_folder") { chooseFolder(for: missing.source) }
                    }
                }
                if let folderError {
                    Text(language.format("import.folder_error", fallback: "No browser profile was found in %1$@. Choose the folder that contains Default or Profile 1.", folderError.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.faint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 2)
        }
    }

    /// macOS protects another app's data. Choosing its folder in the system
    /// panel grants this browser access without asking for Full Disk Access.
    private func chooseFolder(for source: Chromium.Source) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = source.root.deletingLastPathComponent()
        panel.message = language.format("import.choose_folder", fallback: "Choose %1$@'s browser data folder", source.name)
        panel.prompt = language.text("import.use_folder", fallback: "Use Folder")
        panel.begin { answer in
            guard answer == .OK, let folder = panel.url else { return }
            looking = true
            DispatchQueue.global(qos: .userInitiated).async {
                var selected = source
                selected.rootOverride = folder.resolvingSymlinksInPath()
                let found = !selected.profiles.isEmpty
                DispatchQueue.main.async {
                    guard found else {
                        looking = false
                        folderError = folder
                        return
                    }
                    Chromium.useForSession(folder, for: source)
                    folderError = nil
                    previews = [:]
                    profiles = [:]
                    usual = [:]
                    look()
                }
            }
        }
    }

    private func options(for source: ImportSource) -> some View {
        let preview = previews[key(source, profile(of: source))]
        let extensions = fresh(source)
        return Card {
            if case .chromium(let chromium) = source,
               let root = Chromium.chosenRoot(for: chromium.name), !Store.testing {
                Text(language.format("welcome.from", fallback: "From %1$@", root.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .textSelection(.enabled)
                Rule()
            }
            if let record = ImportRecords.of(source.name) {
                Line("ui.brought_before", broughtBefore(record), localizedTitle: true) { EmptyView() }
                Rule()
            }
            if let choices = profiles[source.id], choices.count > 1 {
                Line("ui.profile", localizedTitle: true) {
                    Picker("", selection: Binding(
                        get: { chosen[source.id] ?? usual[source.id] ?? "" },
                        set: { value in
                            chosen[source.id] = value
                            brought = nil
                            count(source)
                        }
                    )) {
                        ForEach(choices) { profile in
                            Text(profile.id == usual[source.id] ? language.format("import.most_recent", fallback: "Most recent: %1$@", profile.name) : profile.name).tag(profile.id)
                        }
                        Divider()
                        Text("ui.all_profiles", bundle: Language.resources).tag("")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                Rule()
            }
            // A kind the browser has none of is said so, and can't be picked.
            Line("ui.passwords_02c830",
                 !source.importsPasswords
                    ? (!source.passwordsInPasswordsApp
                        ? language.format("import.not_supported", fallback: "Not supported for %1$@", source.name)
                        : language.format("import.passwords_app", fallback: "%1$@ keeps them in the Passwords app: export them from there and bring in the CSV file", source.name))
                    : preview?.passwords == 0
                        ? language.format("import.none_in", fallback: "None in %1$@", source.name)
                        : source.asksForKey
                            ? language.format("import.keychain_key", fallback: "macOS asks once for %1$@'s keychain key", source.name)
                            : language.format("import.own_files", fallback: "Read from %1$@'s own files, unless it has a primary password", source.name), localizedTitle: true) {
                option($wantsPasswords, none: !source.importsPasswords || preview?.passwords == 0)
            }
            Rule()
            Line("ui.bookmarks", preview?.bookmarks == 0 ? language.format("import.none_in", fallback: "None in %1$@", source.name) : language.format("import.bookmarks_folder", fallback: "In a “%1$@” folder, or at the top if you have none yet", source.name), localizedTitle: true) {
                option($wantsBookmarks, none: preview?.bookmarks == 0)
            }
            // Brought before: only what is new comes, unless what came from
            // it last time is to go first. An import from before this was
            // kept has nothing recorded, and nothing is guessed at.
            if wantsBookmarks, preview?.bookmarks != 0, let record = ImportRecords.of(source.name) {
                Rule()
                let recorded = !record.bookmarkIDs.isEmpty
                Line(language.format("import.replace_title", fallback: "Replace what came from %1$@ before", source.name),
                     recorded ? language.format("import.replace_detail", fallback: "Its bookmarks from %1$@ go, and these come fresh; passwords only ever add", record.date.formatted(.dateTime.day().month().locale(language.locale)))
                              : language.format("import.nothing_recorded", fallback: "Nothing recorded from %1$@ yet — only what is new comes", source.name)) {
                    option($replaceBookmarks, none: !recorded)
                }
            }
            Rule()
            Line("ui.history", preview?.places == 0 ? language.format("import.none_in", fallback: "None in %1$@", source.name) : language.count("count.last_places", preview.map { $0.places } ?? 3000), localizedTitle: true) {
                option($wantsHistory, none: preview?.places == 0)
            }
            // Its open tabs and tab groups, asleep at the end of this space.
            if source.readsOpenTabs {
                Rule()
                Line("ui.open_tabs_tab_groups", tabsDetail(preview, source), localizedTitle: true) {
                    option($wantsTabs, none: !bringsTabs(source))
                }
            }
            // Arc's own, or Zen's: its spaces, what is pinned in them, its
            // favourites or Essentials.
            if let arc = arcCounts[key(source, profile(of: source))], arc.spaces + arc.pinned > 0 {
                Rule()
                Line("ui.spaces_and_pinned_tabs", arcDetail(arc, source), localizedTitle: true) {
                    Switch(on: $wantsArc)
                }
                // Pinned pages only keep their shape as pinned rows, and
                // those are off until asked for. This is the moment someone
                // would ask, so the sheet offers the switch here, once, rather
                // than bringing them in as tabs and leaving the setting to be
                // found afterwards.
                if wantsArc, arc.pinned > 0, !browser.prefs.listsPins {
                    Rule()
                    Line("ui.keep_them_as_pinned_rows",
                         browser.prefs.sidebar
                            ? language.format("import.pinned_rows", fallback: "As in %1$@: each pinned page a row with its name, under your pins. Turned on, it stays in Settings › Spaces & Pins › Pinned rows", source.name)
                            : language.format("import.pinned_rows_sidebar", fallback: "As in %1$@: each pinned page a row with its name, under your pins. Turned on, it stays in Settings › Spaces & Pins › Pinned rows; rows show with the tabs down the side", source.name), localizedTitle: true) {
                        Pill("ui.turn_on_pinned_rows") {
                            withAnimation(Motion.glide) { browser.prefs.listsPins = true }
                        }
                    }
                }
                // Its folders, as folders of rows rather than tab groups:
                // offered here, the moment they would be wanted, as the rows are.
                if wantsArc, arc.pinned > 0, browser.prefs.listsPins, !browser.prefs.pinFolders {
                    Rule()
                    Line("ui.keep_its_folders_as_folders",
                         language.format("import.keep_folders", fallback: "As in %1$@: each folder of pinned pages a folder of rows, nested as it was, rather than a tab group. Turned on, it stays in Settings › Spaces & Pins › Folders in pinned rows", source.name), localizedTitle: true) {
                        Pill("ui.turn_on_folders") {
                            withAnimation(Motion.glide) { browser.prefs.pinFolders = true }
                        }
                    }
                }
            }
            if !extensions.isEmpty {
                Rule()
                Line("ui.extensions", language.count("count.extensions_found", extensions.count), localizedTitle: true) {
                    Switch(on: $wantsExtensions)
                }
            }
        }
    }

    // MARK: - counting

    private func key(_ source: ImportSource, _ profile: String?) -> String {
        "\(source.id)/\(profile ?? "")"
    }

    /// The profile to read: the one chosen, or the one used most recently;
    /// nil for all of them.
    private func profile(of source: ImportSource) -> String? {
        let id = chosen[source.id] ?? usual[source.id] ?? ""
        return id.isEmpty ? nil : id
    }

    private func detail(of source: ImportSource) -> String {
        guard let preview = previews[key(source, profile(of: source))] else { return language.text("import.counting", fallback: "Counting…") }
        var parts: [String] = []
        if let choices = profiles[source.id], choices.count > 1 { parts.append(language.count("count.profiles", choices.count)) }
        // What it has; a kind it has none of isn't worth a word.
        for (n, key) in [(preview.bookmarks, "count.bookmarks"), (preview.places, "count.places"), (preview.passwords, "count.passwords")] where n > 0 {
            parts.append(language.count(key, n))
        }
        if preview.session.found > 0 { parts.append(language.count("count.open_tabs", preview.session.found)) }
        if let arc = arcCounts[key(source, profile(of: source))], arc.spaces > 0 {
            parts.append(language.count("count.spaces", arc.spaces))
        }
        if let record = ImportRecords.of(source.name) {
            parts.append(language.format("import.brought_date", fallback: "brought %1$@", record.date.formatted(.dateTime.day().month().locale(language.locale))))
        }
        return parts.isEmpty ? language.text("import.nothing_to_bring", fallback: "Nothing to bring in") : parts.joined(separator: " · ")
    }

    /// What was brought from it before, in a line: "312 bookmarks, 1,204
    /// places and 58 passwords, 27 Sep".
    private func broughtBefore(_ record: ImportRecord) -> String {
        let parts = [(record.bookmarks, "count.bookmarks"), (record.places, "count.places"), (record.passwords, "count.passwords"),
                     (record.spaces ?? 0, "count.spaces"), (record.pinned ?? 0, "count.pinned_tabs")]
            .filter { $0.0 > 0 }.map { language.count($0.1, $0.0) }
        let list = ListFormatter()
        list.locale = language.locale
        let what = parts.isEmpty ? language.text("import.nothing_new", fallback: "Nothing new") : (list.string(from: parts) ?? parts.joined(separator: ", "))
        return language.format("import.summary_date", fallback: "%1$@, %2$@", what, record.date.formatted(.dateTime.day().month().locale(language.locale)))
    }

    /// A kind's switch; off and out of reach when there is none of it.
    @ViewBuilder
    private func option(_ on: Binding<Bool>, none: Bool) -> some View {
        if none {
            Switch(on: .constant(false)).disabled(true).opacity(0.4)
        } else {
            Switch(on: on)
        }
    }

    /// The store extensions it has that aren't here already.
    private func fresh(_ source: ImportSource) -> [String] {
        guard #available(macOS 15.4, *), let preview = previews[key(source, profile(of: source))] else { return [] }
        let have = Set(Extensions.shared.installed.map(\.id))
        return preview.extensions.filter { !have.contains($0) }
    }

    /// Every browser on this Mac, its profiles and what each holds, found
    /// off the main thread.
    private func look() {
        let wanted = browser.bringingIn ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
            let found = ImportSource.installed()
            let missing = Chromium.unreadable()
            let lists = found.map { ($0.id, $0.profiles, $0.usual) }
            DispatchQueue.main.async {
                sources = found
                unreadable = missing
                for (id, list, most) in lists {
                    profiles[id] = list
                    usual[id] = most
                }
                pick = found.first { $0.name == wanted } ?? found.first
                looking = false
                found.forEach(count)
            }
        }
    }

    /// What a browser holds in the profile chosen for it, unless counted
    /// already.
    private func count(_ source: ImportSource) {
        let profile = profile(of: source)
        let key = key(source, profile)
        guard previews[key] == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let preview = source.preview(profile: profile)
            let arc = source.arcCounts(profile: profile)
            DispatchQueue.main.async {
                if let arc { arcCounts[key] = arc }
                previews[key] = preview
            }
        }
    }

    // MARK: - bringing

    private func bring(from source: ImportSource) {
        // This import's own answer, not the one before it in the same sheet.
        marksLanded = false
        let profile = profile(of: source)
        let extensions = wantsExtensions ? fresh(source) : []
        // A kind it has none of isn't read at all: no keychain question for
        // a browser with no passwords.
        let preview = previews[key(source, profile)]
        let passwords = wantsPasswords && source.importsPasswords && preview?.passwords != 0
        let marks = wantsBookmarks && preview?.bookmarks != 0
        let places = wantsHistory && preview?.places != 0
        bringing = true
        var said: [Int: Said] = [:]
        let group = DispatchGroup()
        if passwords {
            group.enter()
            // The one moment macOS asks for the key, if the browser keeps one.
            DispatchQueue.global(qos: .userInitiated).async {
                let outcome = Result { try source.read(profile: profile) }
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let found):
                        let kept = browser.keep(found)
                        ImportRecords.note(source.name, passwords: kept)
                        said[0] = .passwords(kept, skipped: found.skipped, undecrypted: found.undecrypted, source: source.name)
                    case .failure(Chromium.Trouble.noPassphrase):
                        said[0] = .noKey(source.name)
                    case .failure(Mozilla.Trouble.primaryPassword):
                        said[0] = .primaryPassword(source.name)
                    case .failure:
                        said[0] = .noPasswords(source.name)
                    }
                    group.leave()
                }
            }
        }
        if marks {
            let (added, already, kept) = browser.takeBookmarks(from: source, profile: profile, replacing: replaceBookmarks)
            marksLanded = added + already > 0
            said[1] = kept ? .bookmarksKept(source.name, added)
                : added == 0 && already == 0 ? .noBookmarks(source.name)
                : already == 0 ? .bookmarks(added) : .bookmarksWithExisting(added, already)
        }
        if places {
            group.enter()
            browser.takePlaces(from: source, profile: profile) { count in
                said[2] = .places(count)
                group.leave()
            }
        }
        if #available(macOS 15.4, *), !extensions.isEmpty {
            // Each from the store, fresh and checked, one question at a time.
            Task { for id in extensions { await Extensions.shared.install(id: id) } }
            said[3] = .extensions(extensions.count)
        }
        if wantsArc, arcCounts[key(source, profile)] != nil, let sidebar = source.arcSidebar(profile: profile) {
            let (spaces, pins, tabs) = browser.takeArc(sidebar, from: source, profile: profile)
            ImportRecords.note(source.name, spaces: spaces, pinned: pins + tabs)
            said[4] = spaces + pins + tabs == 0 ? .arcAlready(source.name) : .arc(spaces, pins, tabs)
        }
        // From what was read when the sheet counted, not read again here.
        if wantsTabs, bringsTabs(source), let session = preview?.session {
            let got = browser.takeSession(session, from: source, profile: profile)
            said[5] = got.tabs + got.pins == 0 ? .sessionAlready(source.name) : .session(got.tabs, got.groups, got.pins)
        }
        group.notify(queue: .main) {
            bringing = false
            brought = said.keys.sorted().compactMap { said[$0] }
        }
    }

    /// One browser to choose, and what it holds.
    private struct Row: View {
        let name: String
        let detail: String
        /// What can come from it at all (ImportSource.canBringLine).
        let can: String
        let chosen: Bool
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(chosen ? Palette.ink : Palette.faint, lineWidth: chosen ? 4.5 : 1.2)
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 13)).foregroundStyle(Palette.ink)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Palette.muted).monospacedDigit()
                    Text(can).font(.system(size: 11)).foregroundStyle(Palette.faint)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(hovering ? Palette.hover : .clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: pick)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }
}
