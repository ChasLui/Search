import SwiftUI

/// Find on Page's words, its two switches and what the page last answered
/// (`Browser.seeking`): the find bar watches it, and nothing else has to.
@MainActor
final class FindState: ObservableObject {
    @Published var needle = ""
    @Published var matchCase = false
    @Published var wholeWords = false
    @Published var missed = false
    @Published var focus = 0
    @Published var result: PageFind.Result?
}

/// Looking for a word on the page. A pill in the top corner, the same white and
/// hairline as everything else that floats, and gone the moment it isn't wanted.
struct FindBar: View {
    @ObservedObject var browser: Browser
    @ObservedObject private var language = Language.shared
    var availableWidth: CGFloat? = nil
    var onPillFrame: ((CGRect) -> Void)? = nil
    /// The words and the page's answer, which `browser` doesn't announce.
    @ObservedObject private var seeking: FindState

    init(browser: Browser) {
        self.browser = browser
        seeking = browser.seeking
    }

    @FocusState private var focused: Bool

    private var narrow: Bool { availableWidth.map { $0 < 290 } ?? false }
    private var fieldWidth: CGFloat {
        guard let availableWidth else { return 150 }
        return max(40, min(160, availableWidth - (narrow ? 80 : 130)))
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                if browser.needle.isEmpty {
                    Text("ui.find_on_page", bundle: Language.resources)
                        .foregroundStyle(Palette.ink.opacity(0.3))
                }
                TextField("", text: $browser.needle)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel(Text("ui.find_on_page", bundle: Language.resources))
                    .accessibilityHint(Text("ui.type_text_to_search_this_page_press_return_to_find_the_", bundle: Language.resources))
                    .focused($focused)
                    .onSubmit { browser.look(forward: true) }
            }
            .font(.system(size: 12.5))
            .frame(width: fieldWidth)

            // "3 of 17", as the page counted it.
            if let status = displayStatus {
                Text(status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(browser.missed ? Color.red.opacity(0.8) : Palette.muted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(status)
                    .accessibilityIdentifier("Find result status")
            }

            // A pane too narrow for them keeps Return and ⇧Return instead.
            if !narrow {
                step("chevron.up", label: "Previous match", help: "Previous match", shortcut: "edit.findPrevious") {
                    browser.look(forward: false)
                }
                step("chevron.down", label: "Next match", help: "Next match", shortcut: "edit.findNext") {
                    browser.look(forward: true)
                }
            }

            Menu {
                Toggle(isOn: $browser.matchCase) { Text("ui.match_case", bundle: Language.resources) }
                    .help(Text("ui.match_uppercase_and_lowercase_letters_exactly", bundle: Language.resources))
                Toggle(isOn: $browser.wholeWords) { Text("ui.whole_words", bundle: Language.resources) }
                    .disabled(browser.findResult?.nativeFallback == true && !browser.wholeWords)
                    .help(Text("ui.match_complete_words_this_option_is_unavailable_for_pdf", bundle: Language.resources))
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(browser.matchCase || browser.wholeWords ? Palette.ink : Palette.muted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text("ui.search_options", bundle: Language.resources))
            .accessibilityHint(Text("ui.choose_whether_to_match_case_or_whole_words", bundle: Language.resources))
            .help(Text("ui.search_options", bundle: Language.resources))

            step("xmark", label: "Close Find on Page", help: "Close the find field and clear its selection.") {
                browser.closeFind()
            }
        }
        .padding(.leading, narrow ? 10 : 16)
        .padding(.trailing, narrow ? 6 : 8)
        .padding(.vertical, 8)
        .background(Palette.ground, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                browser.missed ? Color.red.opacity(0.35) : Palette.hairline,
                lineWidth: 1
            )
        )
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("find")) }) {
            onPillFrame?($0)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 5)
        .padding(.top, 12)
        .padding(.trailing, 14)
        .frame(maxWidth: availableWidth == nil ? nil : .infinity,
               maxHeight: availableWidth == nil ? nil : .infinity, alignment: .topTrailing)
        .coordinateSpace(name: "find")
        .environment(\.locale, language.locale)
        .animation(Motion.quick, value: browser.missed)
        .onAppear(perform: focus)
        .onChange(of: browser.findFocus) { _, _ in focus() }
    }

    private var displayStatus: String? {
        guard browser.findStatus != nil, let result = browser.findResult else { return nil }
        guard result.available else { return language.text("find.unavailable", fallback: "Search unavailable") }
        if result.nativeFallback {
            if browser.wholeWords && !result.wholeWordsAvailable { return language.text("find.whole_words_unavailable", fallback: "Whole words unavailable") }
            return result.found ? language.text("find.match_found", fallback: "Match found") : language.text("find.no_matches", fallback: "No matches")
        }
        guard let index = result.index, let count = result.count, count > 0 else { return language.text("find.no_matches", fallback: "No matches") }
        return language.format("find.result", fallback: "%1$@ of %2$@", index.formatted(), count.formatted() + (result.more ? "+" : ""))
    }

    /// Into the field, and once more a moment later if it didn't take: as
    /// the bar comes in, the field may not be in the window yet, and with
    /// the Mac's keyboard navigation on, the keyboard went to the first
    /// button instead — the back button — until ⌘F was pressed again (#172).
    private func focus() {
        focused = true
        DispatchQueue.main.async {
            if !focused { focused = true }
        }
    }

    private func step(
        _ icon: String,
        label: String,
        help: String,
        shortcut: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(label), bundle: Language.resources))
        .accessibilityHint(Text(LocalizedStringKey(help), bundle: Language.resources))
        .shortcutHelp(Language.shared.text(help, fallback: help), shortcut)
    }
}
