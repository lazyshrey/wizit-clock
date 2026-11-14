import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let bundleID = "com.shrey.wizit"
    private static let showSettingsNotification = Notification.Name("com.shrey.wizit.showSettings")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only ever run one Wizit. A second launch (Finder, DMG copy, login item, `swift run`)
        // would otherwise draw a second clock right on top of the first.
        if isAnotherInstanceRunning() {
            DistributedNotificationCenter.default().postNotificationName(
                Self.showSettingsNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            NSApplication.shared.terminate(nil)
            return
        }

        // Re-opening the app while it's running brings up Settings in the existing instance
        DistributedNotificationCenter.default().addObserver(
            forName: Self.showSettingsNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                DesktopWindowManager.shared.openSettingsWindow()
            }
        }

        // Run as an accessory app (menu bar + desktop widget, clean and dock-free)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Start desktop widget and status item
        DesktopWindowManager.shared.start()
    }

    private func isAnotherInstanceRunning() -> Bool {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myBundleID = Bundle.main.bundleIdentifier ?? Self.bundleID
        return NSWorkspace.shared.runningApplications.contains { app in
            guard app.processIdentifier != myPID, !app.isTerminated else { return false }
            if app.bundleIdentifier == myBundleID || app.bundleIdentifier == Self.bundleID {
                return true
            }
            // Unbundled dev builds (`swift run`) have no bundle ID, so match on the executable name
            return app.executableURL?.lastPathComponent == "Wizit"
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
@MainActor
struct WizitApp {
    private static let delegate = AppDelegate()
    
    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
