import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.showingSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Back to WakeBee")
                .help("Back to WakeBee")
                Text("Settings").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            Picker("Settings section", selection: $model.settingsTab) {
                Text("General").tag(SettingsTab.general)
                Text("Closed Lid").tag(SettingsTab.closedLid)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)
            Divider()
            pages
        }
        .frame(width: 340, height: 440)
        .onAppear { refresh() }
        .onChange(of: model.settingsTab) { refresh() }
    }

    // Keep pages mounted so drafts and scroll positions survive tab changes.
    // Hidden pages cannot receive input, shortcuts, or accessibility focus.
    private var pages: some View {
        ZStack {
            GeneralSettingsView(model: model)
                .modifier(SettingsPageVisibility(isSelected: model.settingsTab == .general))
            ClosedLidSettingsView(model: model)
                .modifier(SettingsPageVisibility(isSelected: model.settingsTab == .closedLid))
        }
    }

    private func refresh() { model.loginItem.refresh(); model.closedLid.refresh() }
}

private struct SettingsPageVisibility: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isSelected ? 1 : 0)
            .disabled(!isSelected)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .zIndex(isSelected ? 1 : 0)
    }
}
