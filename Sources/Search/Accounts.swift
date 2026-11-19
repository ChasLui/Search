import SwiftUI

/// The accounts kept for a site, hanging from the sign-in box the caret is
/// in. The same white and hairline as everything else that floats over a
/// page; one line per account, the name in ink and the site under it in
/// grey; a click puts both into the form. The Mac's passkeys for a page
/// waiting for one come first, as in Safari; a click on one brings up the
/// Mac's sheet for it. Under a box for your name, email, phone or address,
/// your card in Contacts, and a click fills the form. ↓ and ↑ light a row
/// from the keyboard and Return takes it, as a click (App.swift's `take`).
/// It follows the box when the page scrolls, and goes when the caret does.
struct AccountList: View {
    @ObservedObject private var language = Language.shared
    @ObservedObject var browser: Browser
    let asked: Browser.Suggesting
    /// Where the card came out in its host, for a host that has to know
    /// where it is to keep a click on it (see PaneStage's AccountHost).
    var onFrame: ((CGRect) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The rows in the order ↓ walks them (Suggesting.choices): the
            // Mac's passkeys, the page's own host's accounts from both places,
            // then the rest of its site's under a line, so a login saved for
            // example.com is still there on admin.example.com without passing
            // for admin's; codes, the rows about Apple Passwords, your card.
            let choices = asked.choices
            ForEach(Array(choices.enumerated()), id: \.offset) { at, choice in
                if at == asked.othersFrom {
                    Text(language.format("account.other_on", fallback: "Other accounts on %1$@", Vault.registrable(asked.host)))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                }
                row(choice, lit: asked.lit == at)
            }
            if !offerOnly {
            HStack(spacing: 6) {
                Image(systemName: contactsOnly ? "person.crop.rectangle" : "key")
                    .font(.system(size: 9, weight: .medium))
                Text(footer)
                    .font(.system(size: 10.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.faint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Palette.wash.opacity(0.5))
            }
        }
        .frame(width: max(240, min(360, asked.spot.width)), alignment: .leading)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 22, y: 8)
        // Measured inside the offset, so where it is drawn, not laid out.
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(FromTopLeft<AccountList>.space)) }) { onFrame?($0) }
        // Just under the box, left edges lined up. The offset is from the
        // stage's top-left, which is also the web view's.
        .offset(x: asked.spot.minX, y: asked.spot.maxY + 6)
    }

    @ViewBuilder
    private func row(_ choice: Browser.Suggesting.Choice, lit: Bool) -> some View {
        switch choice {
        case .passkey(let passkey):
            Row(mark: .symbol("person.badge.key"), name: passkey.name,
                detail: passkey.provider.map { language.format("account.passkey_provider", fallback: "Passkey · %1$@", $0) }
                    ?? language.text("account.passkey", fallback: "Passkey"), lit: lit) { browser.choose(passkey) }
        case .login(let login):
            Row(mark: .letter(login.user.first.map { String($0).uppercased() } ?? "•"),
                name: login.user.isEmpty ? language.text("account.no_name", fallback: "No name") : login.user, detail: login.host, lit: lit) { browser.choose(login) }
        case .apple(let login):
            // The Mac's Passwords app, when turned on (ApplePasswords.swift):
            // marked as Apple's.
            Row(mark: .letter(login.user.first.map { String($0).uppercased() } ?? "•"),
                name: login.user.isEmpty ? language.text("account.no_name", fallback: "No name") : login.user, detail: language.text("account.apple_passwords", fallback: "Apple Passwords"), lit: lit) { browser.choose(login) }
        case .code(let code):
            Row(mark: .symbol("number"), name: code.user.isEmpty ? language.text("account.code", fallback: "Verification code") : code.user,
                detail: code.user.isEmpty ? language.text("account.apple_passwords", fallback: "Apple Passwords") : language.text("account.code_apple", fallback: "Verification code · Apple Passwords"), lit: lit) { browser.choose(code) }
        case .connect:
            Row(mark: .symbol("key.icloud"), name: language.text("account.connect", fallback: "Connect Apple Passwords…"),
                detail: language.text("account.pair", fallback: "Pair once with a code from your Mac"), lit: lit) { browser.connectApplePasswords() }
        case .offer:
            OfferRow(lit: lit, use: browser.useApplePasswords, never: browser.neverOfferApplePasswords)
        case .contact(let contact):
            // A click fills the form; a shift-click, the box alone.
            Row(mark: .symbol("person.crop.circle"), name: contact.title, detail: contact.detail, lit: lit) {
                browser.choose(contact, alone: NSEvent.modifierFlags.contains(.shift))
            }
            .help(Text("ui.fills_the_form_shift_click_fills_only_this_box", bundle: Language.resources))
        }
    }

    /// Nothing but the offer: no footer under it, the row says it all.
    private var offerOnly: Bool {
        asked.appleOffer != nil && asked.logins.isEmpty && asked.passkeys.isEmpty && asked.apple.isEmpty && asked.codes.isEmpty && !asked.appleConnect
            && asked.contacts.isEmpty
    }

    /// Nothing but your card's rows.
    private var contactsOnly: Bool {
        !asked.contacts.isEmpty && asked.logins.isEmpty && asked.passkeys.isEmpty && asked.apple.isEmpty && asked.codes.isEmpty
            && !asked.appleConnect
    }

    private var footer: String {
        if contactsOnly { return language.text("account.from_contacts", fallback: "From your card in Contacts") }
        if asked.logins.isEmpty && asked.apple.isEmpty && asked.codes.isEmpty && !asked.appleConnect { return language.text("account.passkeys_mac", fallback: "Passkeys on this Mac") }
        if asked.logins.isEmpty { return language.text("account.from_apple", fallback: "From Apple Passwords") }
        return asked.apple.isEmpty ? language.text("From your keychain", fallback: "From your keychain") : language.text("account.from_both", fallback: "From your keychain and Apple Passwords")
    }

    private enum Mark { case letter(String), symbol(String) }

    /// "Use your Apple passwords?", at the bottom: smaller and greyer than
    /// an account, so it never reads as one. A click turns Apple Passwords
    /// on and pairs; the ✕ says don't offer again.
    struct OfferRow: View {
        /// Come to with ↓ and ↑: Return takes it, as a click on it.
        var lit = false
        let use: () -> Void
        let never: () -> Void
        @State private var hovering = false
        @State private var onCross = false

        var body: some View {
            HStack(spacing: 8) {
                Button(action: use) {
                    HStack(spacing: 8) {
                        Image(systemName: "key")
                            .font(.system(size: 9, weight: .medium))
                            .frame(width: 22)
                        Text("ui.use_your_apple_passwords", bundle: Language.resources)
                            .font(.system(size: 11.5))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle((hovering && !onCross) || lit ? Palette.ink : Palette.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Text("ui.turns_on_apple_passwords_and_pairs_with_a_code_from_you", bundle: Language.resources))
                Button(action: never) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                        .frame(width: 16, height: 16)
                        .background(Palette.ink.opacity(onCross ? 0.07 : 0), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { onCross = $0 }
                .help(Text("ui.don_t_offer_again", bundle: Language.resources))
                .accessibilityLabel(Text("ui.don_t_offer_again", bundle: Language.resources))
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(hovering || lit ? Palette.hover : .clear)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
            .animation(Motion.quick, value: onCross)
        }
    }

    private struct Row: View {
        let mark: Mark
        let name: String
        let detail: String
        /// Come to with ↓ and ↑: lit as under the pointer.
        var lit = false
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: pick) {
                HStack(spacing: 10) {
                    Group {
                        switch mark {
                        case .letter(let letter): Text(letter).font(.system(size: 11, weight: .medium))
                        case .symbol(let name): Image(systemName: name).font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(hovering || lit ? Palette.hover : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }
}

extension Browser.Suggesting {
    /// One row of the list, which a click or Return on it picks.
    enum Choice: Equatable {
        case passkey(Passkeys.Offered)
        case login(Kept)
        case apple(AppleLogin)
        case code(AppleCode)
        /// "Connect Apple Passwords…"
        case connect
        /// "Use your Apple passwords?"
        case offer
        case contact(MeCard.Offer)
    }

    /// The rows top to bottom, as drawn and as ↓ walks them.
    var choices: [Choice] {
        passkeys.map(Choice.passkey) + ownLogins.map(Choice.login) + ownApple.map(Choice.apple)
            + siteLogins.map(Choice.login) + siteApple.map(Choice.apple) + codes.map(Choice.code)
            + (appleConnect ? [.connect] : []) + (appleOffer != nil ? [.offer] : []) + contacts.map(Choice.contact)
    }

    /// Where "Other accounts on …" goes, before the first of the rest of the
    /// site's accounts: only when this host has some of its own above them.
    var othersFrom: Int? {
        guard !(ownLogins.isEmpty && ownApple.isEmpty), !(siteLogins.isEmpty && siteApple.isEmpty) else { return nil }
        return passkeys.count + ownLogins.count + ownApple.count
    }

    private var ownLogins: [Kept] { logins.filter { Vault.belongs($0.host, to: host, wide: false) } }
    private var siteLogins: [Kept] { logins.filter { !Vault.belongs($0.host, to: host, wide: false) } }
    private var ownApple: [AppleLogin] { apple.filter { owns($0) } }
    private var siteApple: [AppleLogin] { apple.filter { !owns($0) } }

    private func owns(_ login: AppleLogin) -> Bool {
        appleHost.map { ApplePasswords.belongs(login.sites, to: $0, wide: false) } ?? false
    }
}
