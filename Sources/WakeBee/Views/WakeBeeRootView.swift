import SwiftUI

struct WakeBeeRootView: View {
    let model: AppModel

    var body: some View {
        if model.showingSettings {
            SettingsView(model: model)
        } else {
            SessionPanel(model: model)
        }
    }
}
