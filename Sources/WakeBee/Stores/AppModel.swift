import WakeBeeCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    let preferences: Preferences
    let session: SessionController
    let closedLid = ClosedLidService()
    let loginItem = LoginItemService()
    var durationDraft: DurationDraft
    var sessionMode = SessionMode.duration
    var sessionEndDate = Date.now.addingTimeInterval(30 * 60)
    var settingsTab = SettingsTab.general
    var showingSettings = false
    var isPopoverVisible = false
    private(set) var blockedStartAttempts = 0
    @ObservationIgnored private var sessionMonitor: SessionMonitor?

    init() {
        let preferences = Preferences()
        self.preferences = preferences
        self.durationDraft = DurationDraft(totalMinutes: preferences.initialMinutes)
        let session = SessionController(power: PowerAssertionService(),
                                        keepDisplayAwake: preferences.keepDisplayAwake)
        self.session = session
        self.sessionMonitor = SessionMonitor(session: session, beforeRefresh: { [weak self] in
            self?.synchronizeSafeguards()
        }) { [weak self] hasDemand in
            guard let self else { return }
            self.closedLid.update(hasDemand: hasDemand, policy: self.preferences.closedLidPolicy)
        }
    }

    func showSettings(_ tab: SettingsTab) {
        settingsTab = tab
        showingSettings = true
    }

    func start() {
        guard !session.isActive, let duration = requestedSession else { return }
        synchronizeSafeguards()
        session.updatePowerSafety(policy: preferences.sessionPowerPolicy, state: SystemPowerState.snapshot)
        if session.start(duration) {
            preferences.remember(duration)
        } else if session.statusMessage != nil {
            blockedStartAttempts += 1
        }
        refreshSession()
    }

    func end() {
        session.end()
        refreshSession()
    }

    func extend() {
        synchronizeSafeguards()
        session.extend()
        refreshSession()
    }

    func setDisplayAwake(_ enabled: Bool) {
        if session.setKeepDisplayAwake(enabled) { preferences.keepDisplayAwake = enabled }
    }

    func setupClosedLid() {
        closedLid.enableAfterSetup()
    }

    func setClosedLid(_ enabled: Bool) {
        closedLid.setEnabled(enabled)
        sessionMonitor?.refresh()
    }

    func handleSystemSleep() {
        closedLid.setEnabled(false)
        session.end(reason: .systemSleep)
    }

    private func refreshSession() {
        sessionMonitor?.refresh()
    }

    var requestedSession: SessionDuration? {
        switch sessionMode {
        case .duration: durationDraft.duration
        case .untilTime: .until(Calendar.current.dateInterval(of: .minute, for: sessionEndDate)?.start ?? sessionEndDate)
        case .untilStopped: .indefinitely
        }
    }

    func refreshPowerSettings() {
        synchronizeSafeguards()
        refreshSession()
    }

    private func synchronizeSafeguards() {
        let wasActive = session.isActive
        if session.isActive {
            session.updatePowerSafety(policy: preferences.sessionPowerPolicy, state: SystemPowerState.snapshot)
        }
        if wasActive && !session.isActive { closedLid.setEnabled(false) }
    }

    func shutdown() {
        sessionMonitor?.stop()
        closedLid.setEnabled(false)
        session.end()
    }
}

enum SettingsTab: Hashable { case general, closedLid }
enum SessionMode: String, CaseIterable, Identifiable {
    case duration, untilTime, untilStopped
    var id: Self { self }
    var label: String {
        switch self {
        case .duration: "For a duration"
        case .untilTime: "Until a specific time"
        case .untilStopped: "Until I stop it"
        }
    }
}
