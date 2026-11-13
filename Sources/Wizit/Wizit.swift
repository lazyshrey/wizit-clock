import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory app (menu bar + desktop widget, clean and dock-free)
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Start desktop widget and status item
        DesktopWindowManager.shared.start()
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
