import Foundation
import ServiceManagement

public final class LaunchAtLoginManager: @unchecked Sendable {
    public static let shared = LaunchAtLoginManager()
    
    private init() {}
    
    public var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                let status = SMAppService.mainApp.status
                return status == .enabled
            }
            return UserDefaults.standard.bool(forKey: "launchAtStartup")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtStartup")
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        if SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    }
                } catch {
                    print("ServiceManagement toggle error: \(error)")
                }
            }
        }
    }
}
