import SwiftUI

/// The same site permission question in a browser or a small popup window.
struct CaptureQuestion: View {
    @ObservedObject var browser: Browser
    @ObservedObject private var language = Language.shared
    let ask: Browser.CaptureAsk

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { question; actions }.fixedSize()
            VStack(alignment: .leading, spacing: 12) {
                question
                ViewThatFits(in: .horizontal) {
                    actions.fixedSize()
                    VStack(alignment: .leading, spacing: 10) { buttons }
                }
            }
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
    }

    private var question: some View {
        HStack(spacing: 12) {
            Image(systemName: ask.wants == "location" ? "location" : ask.wants == "microphone" ? "mic" : ask.wants == "notifications" ? "bell"
                  : ask.wants == "cookies" ? "person.crop.circle" : "video")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
            Text(captureQuestion)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var captureQuestion: String {
        switch ask.wants {
        case "location": return language.format("permission.location", fallback: "%@ wants to know your location", ask.host)
        case "notifications": return language.format("permission.notifications", fallback: "%@ wants to send you notifications", ask.host)
        case "camera": return language.format("permission.camera", fallback: "%@ wants to use your camera", ask.host)
        // Safari's question, in fewer words: a yes lets the framed site know
        // you were on this one.
        case "cookies": return language.format("permission.cookies", fallback: "%1$@ wants to use its cookies and website data on %2$@, which also lets it see you were there", ask.host, ask.under)
        case "microphone": return language.format("permission.microphone", fallback: "%@ wants to use your microphone", ask.host)
        default: return language.format("permission.camera_microphone", fallback: "%@ wants to use your camera and microphone", ask.host)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) { buttons }
    }

    @ViewBuilder
    private var buttons: some View {
        Button { ask.once ? browser.allowCaptureOnce() : browser.allowCapture() } label: {
            Text(LocalizedStringKey(ask.once ? "Allow once" : "Allow"), bundle: Language.resources)
                .foregroundStyle(Palette.ground)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Palette.ink, in: Capsule())
        }
        if ask.once, ask.keeps {
            Button { browser.allowCapture() } label: { Text("ui.always_allow", bundle: Language.resources) }
                .foregroundStyle(Palette.ink)
        }
        Button { browser.denyCapture() } label: { Text("ui.don_t_allow", bundle: Language.resources) }
            .foregroundStyle(Palette.muted)
    }
}

/// A page asking to share the screen (Browser.askedToShareScreen): nothing
/// is shared until a screen or a window is picked in macOS's own picker,
/// which only these two answers open.
struct ScreenQuestion: View {
    @ObservedObject var browser: Browser
    @ObservedObject private var language = Language.shared
    let ask: Browser.CaptureAsk

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)
                Text(ask.sound
                     ? language.format("permission.screen_sound", fallback: "%@ wants to share your screen and your Mac's sound", ask.host)
                     : language.format("permission.screen", fallback: "%@ wants to share your screen", ask.host))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button { browser.denyShare() } label: {
                    Text("ui.don_t_allow", bundle: Language.resources)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                Spacer(minLength: 8)
                // A window gives away less than a whole screen: it is the
                // one drawn as the answer.
                Button { browser.shareScreen() } label: {
                    Text("ui.share_a_screen", bundle: Language.resources)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                Button { browser.shareWindow() } label: {
                    Text("ui.share_a_window", bundle: Language.resources)
                        .foregroundStyle(Palette.ground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Palette.ink, in: Capsule())
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.ink)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 400, alignment: .leading)
        .padding(18)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
        .padding(.horizontal, 16)
    }
}

/// A password offer remains readable in the popup that submitted the form.
struct PasswordOffer: View {
    @ObservedObject var browser: Browser
    @ObservedObject private var language = Language.shared
    let offer: Browser.Offer

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { question; actions }.fixedSize()
            VStack(alignment: .leading, spacing: 12) {
                question
                ViewThatFits(in: .horizontal) {
                    actions.fixedSize()
                    VStack(alignment: .leading, spacing: 10) { buttons }
                }
            }
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
    }

    private var question: some View {
        let login = offer.login
        return Text(offer.changed
             ? language.format("password.update", fallback: "Update the password for %@ on %@?", login.user, login.host)
             : (login.user.isEmpty
                ? language.format("password.save_site", fallback: "Save this password for %@?", login.host)
                : language.format("password.save_user", fallback: "Save the password for %@ on %@?", login.user, login.host)))
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View { HStack(spacing: 12) { buttons } }

    @ViewBuilder
    private var buttons: some View {
        Button { browser.keepOffer() } label: {
            Text(LocalizedStringKey(offer.changed ? "Update" : "Save"), bundle: Language.resources)
        }
            .foregroundStyle(Palette.ground)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Palette.ink, in: Capsule())
        Button { browser.dropOffer() } label: { Text("ui.not_now", bundle: Language.resources) }
            .foregroundStyle(Palette.muted)
        if !offer.changed {
            Button { browser.neverOffer() } label: { Text("ui.never_here", bundle: Language.resources) }
                .foregroundStyle(Palette.muted)
        }
    }
}
