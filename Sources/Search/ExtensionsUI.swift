import SwiftUI
import WebKit

/// Settings › Extensions: what is installed, and the two ways in — a Chrome
/// Web Store link, or a folder.
struct ExtensionsPage: View {
    @ObservedObject var browser: Browser

    var body: some View {
        if #available(macOS 15.4, *) {
            Installer(browser: browser, extensions: .shared)
        } else {
            Card {
                Line("ui.chrome_extensions", "ui.need_macos_15_4_or_later_the_version_whose_webkit_can_r", localizedTitle: true, localizedDetail: true) { EmptyView() }
            }
        }
    }

    @available(macOS 15.4, *)
    private struct Installer: View {
        @ObservedObject var browser: Browser
        @ObservedObject var extensions: Extensions
        @State private var link = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("ui.add_from_the_chrome_web_store", bundle: Language.resources)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: 8)
                            Pill("ui.open_the_store") {
                                browser.open(Browser.webStore, foreground: true)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                if link.isEmpty {
                                    Text("ui.paste_a_link_to_an_extension_or_its_id", bundle: Language.resources)
                                        .foregroundStyle(Palette.muted.opacity(0.8))
                                }
                                TextField("", text: $link)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Palette.ink)
                                    .onSubmit(add)
                            }
                            .font(.system(size: 12.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            if !extensions.busy.isEmpty {
                                Ring(size: 12)
                            } else {
                                Pill("ui.add", filled: true, action: add)
                                    .disabled(Crx.id(in: link) == nil)
                            }
                        }
                        Text("ui.or_find_it_in_the_store_and_press_add_to_search_on_its_", bundle: Language.resources)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                }

                Card {
                    Line("ui.from_another_browser", "ui.what_chrome_arc_brave_and_the_others_added_from_the_chr", localizedTitle: true, localizedDetail: true) {
                        Pill("ui.bring_them_over") {
                            browser.bringingExtensions = true
                            browser.lead(to: InternalPage(.importing))
                        }
                    }
                }

                if extensions.installed.isEmpty {
                    Card { Nothing("ui.no_extensions_yet") }
                } else {
                    Card {
                        ForEach(Array(extensions.installed.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Rule() }
                            Row(item: item, extensions: extensions)
                        }
                    }
                    Text("ui.each_extension_stays_out_of_private_tabs_until_you_allo", bundle: Language.resources)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Recorders()

                Card {
                    Line("ui.load_an_unpacked_extension", "ui.a_folder_with_a_manifest_json_your_own_or_one_exported_", localizedTitle: true, localizedDetail: true) {
                        Pill("ui.choose") { extensions.installFolder() }
                    }
                }

                FromSafariApps(extensions: extensions)
            }
        }

        private func add() {
            guard Crx.id(in: link) != nil else { return }
            extensions.install(from: link)
            link = ""
        }
    }

    /// Safari web extensions inside the apps on this Mac (SafariApps), off
    /// unless you turn it on: only then are the Applications folders looked
    /// through.
    @available(macOS 15.4, *)
    private struct FromSafariApps: View {
        @ObservedObject var extensions: Extensions
        @State private var on = SafariApps.on
        @State private var found: [SafariApps.Found] = []

        var body: some View {
            Card {
                VStack(spacing: 0) {
                    Line("settings.extensions.safariApps.title", "extensions.safari_apps_detail", localizedTitle: true, localizedDetail: true) {
                        Switch(on: $on)
                    }
                    if on {
                        if found.isEmpty {
                            Rule()
                            Nothing("ui.no_safari_extensions")
                        }
                        ForEach(found, id: \.id) { item in
                            Rule()
                            Line(item.name, Language.shared.format("ui.in_app", fallback: "In %1$@", item.app)) {
                                if extensions.installed.contains(where: { $0.id == item.id }) {
                                    Text("ui.added", bundle: Language.resources).font(.system(size: 12)).foregroundStyle(Palette.muted)
                                } else {
                                    Pill("Add") { SafariApps.add(item, to: extensions) }
                                }
                            }
                        }
                    }
                }
            }
            .onAppear { if on { look() } }
            .onChange(of: on) { _, now in
                Store.settings.set(now, forKey: SafariApps.key)
                if now { look() } else { found = [] }
            }
        }

        private func look() {
            Task.detached(priority: .userInitiated) {
                let all = SafariApps.scan()
                await MainActor.run { found = all }
            }
        }
    }

    /// The extensions you let record your screen, each one to take back.
    @available(macOS 15.4, *)
    private struct Recorders: View {
        @ObservedObject private var capture = ExtensionCapture.shared

        var body: some View {
            let ids = ExtensionCapture.allowedIDs
            if !ids.isEmpty {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                            if index > 0 { Rule() }
                            Line(Browser.extensionName(id), "ui.can_record_your_screen_macos_asks_what_to_share_each_ti", localizedDetail: true) {
                                Pill("ui.remove") { ExtensionCapture.forget(id) }
                            }
                        }
                    }
                }
            }
        }
    }

    @available(macOS 15.4, *)
    private struct Row: View {
        @ObservedObject private var language = Language.shared
        let item: Installed
        @ObservedObject var extensions: Extensions
        @State private var hovering = false

        var body: some View {
            let context = extensions.contexts[item.id]
            let sites = context.map(Extensions.asksForSites) == true
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Group {
                        if let icon = context?.webExtension.icon(for: CGSize(width: 32, height: 32)) {
                            Image(nsImage: icon).resizable().interpolation(.high)
                        } else {
                            Image(systemName: "puzzlepiece.extension").foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(detail(context))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                            .help(item.source ?? "")
                        // Switched on and not running: said as such, with
                        // WebKit's reason, not a row like any other (#1208).
                        if item.enabled, context == nil, let reason = extensions.notStarted[item.id] {
                            Text(Language.shared.format("extension.could_not_start_reason", fallback: "Couldn’t start: %1$@", reason))
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.unsafe)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        // Running, but without what it is for (#1208).
                        if let limit = context.flatMap({ Extensions.localizedCantDo($0.webExtension.manifest) }) {
                            Text(limit)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.unsafe)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    Spacer(minLength: 8)
                    if sites {
                        RunsOn(item: item, extensions: extensions)
                    }
                    // Five pills don't fit beside the name in a settings page's
                    // width, and wrapped a letter at a time when they tried. One
                    // menu holds them all, there without hovering to find it.
                    Menu { actions(context) } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(hovering ? Palette.ink : Palette.muted)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel(Text(Language.shared.format("extension.more", fallback: "More for %1$@", item.name)))
                    .help(Text(Language.shared.format("extension.more", fallback: "More for %1$@", item.name)))
                    Switch(on: Binding(get: { item.enabled }, set: { extensions.setEnabled(item.id, $0) }))
                }
                if sites, extensions.siteAccess(item.id).restricted {
                    SiteList(item: item, extensions: extensions)
                        .padding(.leading, 34)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(hovering ? Palette.hover : .clear)
            .onHover { hovering = $0 }
            .contextMenu { actions(context) }
        }

        @ViewBuilder
        private func actions(_ context: WKWebExtensionContext?) -> some View {
            Button {
                extensions.setPinned(item.id, !(item.pinned ?? false))
            } label: { Text(LocalizedStringKey(item.pinned == true ? "Unpin" : "Pin to Toolbar"), bundle: Language.resources) }
            if context?.overrideNewTabPageURL != nil {
                let on = extensions.newTabPageID == item.id
                Button {
                    extensions.setNewTabPage(on ? nil : item.id)
                } label: { Text(LocalizedStringKey(on ? "extension.stop_new_tabs" : "extension.show_new_tabs"), bundle: Language.resources) }
            }
            if context?.optionsPageURL != nil {
                Button { extensions.openOptions(item.id) } label: { Text("ui.options", bundle: Language.resources) }
            }
            if item.source != nil || !item.fromStore {
                Button { extensions.reload(item.id) } label: { Text("ui.reload", bundle: Language.resources) }
            }
            if let context {
                Divider()
                if (context.webExtension.manifest["incognito"] as? String) == "not_allowed" {
                    Text("ui.private_tabs_aren_t_supported", bundle: Language.resources)
                } else {
                    Toggle(isOn: Binding(
                        get: { context.hasAccessToPrivateData },
                        set: { extensions.setPrivate(item.id, $0) }
                    )) { Text("ui.allow_in_private_tabs", bundle: Language.resources) }
                    .accessibilityLabel(Text(Language.shared.format("extension.allow_private", fallback: "Allow %1$@ in private tabs", item.name)))
                    .help(Text("ui.private_tabs_opened_before_any_extension_was_allowed_ne", bundle: Language.resources))
                }
            }
            Divider()
            Button(role: .destructive) { extensions.remove(item.id) } label: { Text("Remove", bundle: Language.resources) }
        }

        /// Where it was loaded from, by the folder's name — the whole path
        /// is in the tooltip.
        private var folder: String {
            item.source.map { Language.shared.format("extension.from_folder_name", fallback: "From “%1$@”", URL(fileURLWithPath: $0).lastPathComponent) }
                ?? Language.shared.text("extension.from_folder", fallback: "From a folder")
        }

        private func detail(_ context: WKWebExtensionContext?) -> String {
            var parts = [Language.shared.format("extension.version", fallback: "Version %1$@", item.version), item.fromStore ? "Chrome Web Store" : folder]
            if item.enabled, context == nil, extensions.notStarted[item.id] == nil { parts.append(Language.shared.text("extension.could_not_start", fallback: "couldn't start")) }
            if extensions.newTabPageID == item.id {
                parts.append(Language.shared.text("extension.shows_in_new_tabs", fallback: "shows in new tabs"))
            }
            if context?.hasAccessToPrivateData == true { parts.append(Language.shared.text("extension.allowed_private", fallback: "allowed in private tabs")) }
            if let errors = context.map(Extensions.errors(of:)), !errors.isEmpty { parts.append(Language.shared.count("count.warnings", errors.count)) }
            return parts.joined(separator: " · ")
        }
    }
}

/// An extension's "Runs on": every site it asked for (the default), the
/// ones you name, or only where you click its button.
@available(macOS 15.4, *)
private struct RunsOn: View {
    @ObservedObject private var language = Language.shared
    let item: Installed
    @ObservedObject var extensions: Extensions

    var body: some View {
        let access = extensions.siteAccess(item.id)
        Menu {
            Picker(selection: Binding(
                get: { access.mode },
                set: { extensions.setSiteAccess(item.id, SiteAccess(mode: $0, hosts: access.hosts)) }
            )) {
                Text("ui.all_sites_it_asks_for", bundle: Language.resources).tag(SiteAccess.Mode.all)
                Text("ui.only_sites_i_name", bundle: Language.resources).tag(SiteAccess.Mode.some)
                Text("ui.only_when_i_click_it", bundle: Language.resources).tag(SiteAccess.Mode.click)
            } label: { Text("ui.runs_on", bundle: Language.resources) }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 3) {
                Text(LocalizedStringKey(access.mode.title), bundle: Language.resources)
                    .font(.system(size: 11.5))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(access.restricted ? Palette.ink : Palette.muted)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Palette.wash, in: Capsule())
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(Language.shared.format("extension.runs_on", fallback: "%1$@ runs on", item.name)))
        .accessibilityValue(Text(LocalizedStringKey(access.mode.title), bundle: Language.resources))
        .help(Text(Language.shared.format("extension.where_runs", fallback: "Where %1$@ runs. Fewer sites, less memory on the rest", item.name)))
    }
}

/// Under an extension held to fewer sites: the sites you named, one to add,
/// and a word on what that means.
@available(macOS 15.4, *)
private struct SiteList: View {
    @ObservedObject private var language = Language.shared
    let item: Installed
    @ObservedObject var extensions: Extensions
    @State private var typed = ""

    var body: some View {
        let access = extensions.siteAccess(item.id)
        VStack(alignment: .leading, spacing: 6) {
            if access.mode == .some {
                ForEach(access.hosts, id: \.self) { host in
                    HStack(spacing: 6) {
                        Text(host)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Button {
                            extensions.setSiteAccess(item.id, access.removing(host))
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Palette.muted)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(Language.shared.format("extension.remove_host", fallback: "Remove %1$@", host)))
                        .help(Text(Language.shared.format("extension.remove_host", fallback: "Remove %1$@", host)))
                    }
                }
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        if typed.isEmpty {
                            Text("ui.add_a_site_like_example_com", bundle: Language.resources)
                                .foregroundStyle(Palette.muted.opacity(0.8))
                        }
                        TextField("", text: $typed)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Palette.ink)
                            .onSubmit(add)
                            .accessibilityLabel(Text(Language.shared.format("extension.add_site", fallback: "Add a site for %1$@", item.name)))
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Pill("ui.add", action: add)
                        .disabled(SiteAccess.host(from: typed) == nil)
                }
            }
            Text(note(access))
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func add() {
        guard let host = SiteAccess.host(from: typed) else { return }
        extensions.setSiteAccess(item.id, extensions.siteAccess(item.id).adding(host))
        typed = ""
    }

    private func note(_ access: SiteAccess) -> String {
        var out = access.mode == .some
            ? Language.shared.text("extension.some_sites_detail", fallback: "Subdomains included. Elsewhere it runs once you click its button, on that tab until it leaves the site.")
            : Language.shared.text("extension.click_detail", fallback: "It runs on a page once you click its button there, on that tab until it leaves the site.")
        if SiteAccess.needsEverySite(name: item.name, said: Extensions.settings(for: item.id)) {
            out += " " + Language.shared.format("extension.may_need_all", fallback: "%1$@ may need every site to fill in sign-ins.", item.name)
        }
        return out
    }
}

/// On an extension's page in the Chrome Web Store, the offer to add it —
/// where the store's own button only says "Switch to Chrome".
struct StoreOffer: View {
    @ObservedObject var browser: Browser

    var body: some View {
        if #available(macOS 15.4, *), let tab = browser.active {
            Watch(tab: tab, extensions: .shared)
        }
    }

    @available(macOS 15.4, *)
    private struct Watch: View {
        @ObservedObject var tab: Tab
        @ObservedObject var extensions: Extensions

        var body: some View {
            // Only where the page's own "Add to Search" isn't in place — a
            // store that has changed its markup still gets a way in.
            if let url = tab.address, let id = Crx.storeID(of: url),
               tab.storePlaced != id, !extensions.installed.contains(where: { $0.id == id }) {
                HStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Text(LocalizedStringKey(extensions.busy.contains(id) ? "Adding…" : "Add this extension to Search"), bundle: Language.resources)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.ink)
                    if extensions.busy.contains(id) {
                        Ring(size: 10)
                    } else {
                        Button { extensions.install(from: id) } label: { Text("ui.add", bundle: Language.resources) }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ground)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Palette.ink, in: Capsule())
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .padding(.vertical, 9)
                .background(Palette.ground, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    static func isStorePage(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil else { return false }
        let host = url.host()?.lowercased() ?? ""
        return host == "chromewebstore.google.com"
            || (host == "chrome.google.com" && url.path.hasPrefix("/webstore"))
    }
}

/// Settings › Browsing › Searching › Home page: what a new tab opens to, while an
/// extension offers a page for it. Search's own page with the address field
/// ready, or the page of an extension that asked to take its place, and
/// the way back from one that did. With nothing offered there is nothing to
/// pick, so the line isn't there at all, and neither is its hairline.
struct HomePageLine: View {
    var body: some View {
        if #available(macOS 15.4, *) {
            Chooser(extensions: .shared)
        }
    }

    @available(macOS 15.4, *)
    private struct Chooser: View {
        @ObservedObject private var language = Language.shared
        @ObservedObject var extensions: Extensions

        var body: some View {
            let askers = extensions.newTabAskers
            let current = extensions.newTabPageID
            if !askers.isEmpty {
                Rule()
                SettingRow(icon: "house", title: language.text("Home page", fallback: "Home page"), detail: detail(askers, current)) {
                    Picker("", selection: Binding(
                        get: { current ?? "" },
                        set: { extensions.setNewTabPage($0.isEmpty ? nil : $0) }
                    )) {
                        Text("ui.search_s_own", bundle: Language.resources).tag("")
                        Divider()
                        ForEach(askers) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }

        private func detail(_ askers: [Installed], _ current: String?) -> String {
            if let current, let name = askers.first(where: { $0.id == current })?.name {
                return language.format("extension.new_tab.current", fallback: "New tabs show %1$@'s page, since you let it replace them", name)
            }
            return askers.count == 1
                ? language.format("extension.new_tab.single", fallback: "New tabs open blank. %1$@ asked to show its page instead", askers[0].name)
                : language.count("count.extension_new_tab", askers.count)
        }
    }
}
