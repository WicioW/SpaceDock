import Sparkle
import SwiftUI

/// In-app updates through Sparkle (docs/distribution.md, M5): once a day it reads the appcast of
/// the latest GitHub release and offers "a new version is available → install". An update must
/// carry our EdDSA signature (SUPublicEDKey) and the same code signature (SpaceDock certificate),
/// so the Accessibility grant stays. Feed and key come from Info.plist (tools/make-app.sh); without
/// them (`swift run`, CLI commands) there is no updater.
enum Updates {
    static let controller: SPUStandardUpdaterController? =
        Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") == nil ? nil
            : SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    static func check() { controller?.checkForUpdates(nil) }
}

struct CheckForUpdatesButton: View {
    var body: some View {
        Button("Sprawdź aktualizacje…") { Updates.check() }
            .disabled(Updates.controller == nil)
    }
}

/// Sparkle keeps this setting in our defaults under its own key, so the toggle just watches it.
struct AutoUpdateToggle: View {
    @AppStorage("SUEnableAutomaticChecks") private var on = true

    var body: some View {
        if let updater = Updates.controller?.updater {
            Toggle("Sprawdzaj aktualizacje automatycznie",
                   isOn: Binding(get: { on }, set: { updater.automaticallyChecksForUpdates = $0 }))
        }
    }
}
