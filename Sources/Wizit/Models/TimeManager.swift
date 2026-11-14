import SwiftUI
import Combine

@MainActor
public final class TimeManager: ObservableObject {
    public static let shared = TimeManager()
    
    // Core published time strings - only publish when values actually change!
    @Published public var hoursString: String = "12"
    @Published public var minutesString: String = "00"
    @Published public var secondsString: String = "00"
    @Published public var amPmString: String = "AM"
    @Published public var weekdayString: String = "Monday"
    @Published public var dateFormattedString: String = "Jan 1"
    
    // Internal timestamp (not published to avoid re-rendering SwiftUI on every subsecond tick!)
    public var currentDate: Date = Date()
    
    private var tickTimer: Timer?
    private let formatter = DateFormatter()
    
    private init() {
        updateTime()
        scheduleNextTick()
    }
    
    /// Fires just after each whole second, so digits change exactly when the second ticks over
    /// instead of up to half a second late (which made the roll start at uneven times).
    /// Rescheduled every tick so it never drifts off the second boundary.
    private func scheduleNextTick() {
        let now = Date().timeIntervalSinceReferenceDate
        let next = Date(timeIntervalSinceReferenceDate: floor(now) + 1.0 + 0.005)
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateTime()
                self?.scheduleNextTick()
            }
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }
    
    public func updateTime() {
        let now = Date()
        currentDate = now
        
        let settings = AppSettings.shared
        formatter.locale = Locale.current
        
        // 1. Hours & AM/PM (No leading zero in 24h: "1:34" instead of "01:34")
        if settings.is24Hour {
            formatter.dateFormat = "H"
            let newHours = formatter.string(from: now)
            if newHours != hoursString {
                hoursString = newHours
            }
            if !amPmString.isEmpty {
                amPmString = ""
            }
        } else {
            formatter.dateFormat = "h"
            let newHours = formatter.string(from: now)
            if newHours != hoursString {
                hoursString = newHours
            }
            formatter.dateFormat = "a"
            let newAmPm = formatter.string(from: now).uppercased()
            if newAmPm != amPmString {
                amPmString = newAmPm
            }
        }
        
        // 2. Minutes
        formatter.dateFormat = "mm"
        let newMinutes = formatter.string(from: now)
        if newMinutes != minutesString {
            minutesString = newMinutes
        }
        
        // 3. Seconds (only update if seconds are enabled)
        if settings.showSeconds {
            formatter.dateFormat = "ss"
            let newSeconds = formatter.string(from: now)
            if newSeconds != secondsString {
                secondsString = newSeconds
            }
        }
        
        // 4. Weekday & Date (Native macOS Lock Screen Format: Sat 14 Nov)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "E d MMM"
        let newDateStr = formatter.string(from: now)
        if newDateStr != dateFormattedString {
            dateFormattedString = newDateStr
        }
        
        formatter.dateFormat = "EEEE"
        let newWeekday = formatter.string(from: now)
        if newWeekday != weekdayString {
            weekdayString = newWeekday
        }
    }
}
