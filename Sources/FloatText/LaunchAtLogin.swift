import Foundation
import ServiceManagement
import OSLog

/// Thin wrapper over SMAppService. From an unsigned local dev build, this may
/// silently no-op or report .notRegistered — per the plan, that's acceptable
/// and we surface the actual state from SMAppService rather than from cached
/// UserDefaults.
enum LaunchAtLogin {
    private static let log = Logger(subsystem: "com.floattext", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Launch at login toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
