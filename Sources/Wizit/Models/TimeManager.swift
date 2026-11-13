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
    
    private var timerCancellable: AnyCancellable?
    
    private init() {
        updateTime(animated: false)
        // Timer runs once per second (or 0.5s) to check for time transitions smoothly without flood
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTime(animated: true)
            }
    }
    
    public func updateTime(animated: Bool = true) {
        let now = Date()
        currentDate = now
        
        let settings = AppSettings.shared
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // 1. Hours & AM/PM (No leading zero in 24h: "1:34" instead of "01:34")
        if settings.is24Hour {
            formatter.dateFormat = "H"
            let newHours = formatter.string(from: now)
            if newHours != hoursString {
                if animated {
                    withAnimation(.snappy(duration: 0.55, extraBounce: 0.08)) {
                        hoursString = newHours
                    }
                } else {
                    hoursString = newHours
                }
            }
            if !amPmString.isEmpty {
                amPmString = ""
            }
        } else {
            formatter.dateFormat = "h"
            let newHours = formatter.string(from: now)
            if newHours != hoursString {
                if animated {
                    withAnimation(.snappy(duration: 0.55, extraBounce: 0.08)) {
                        hoursString = newHours
                    }
                } else {
                    hoursString = newHours
                }
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
            if animated {
                withAnimation(.snappy(duration: 0.55, extraBounce: 0.08)) {
                    minutesString = newMinutes
                }
            } else {
                minutesString = newMinutes
            }
        }
        
        // 3. Seconds (only update if seconds are enabled)
        if settings.showSeconds {
            formatter.dateFormat = "ss"
            let newSeconds = formatter.string(from: now)
            if newSeconds != secondsString {
                if animated {
                    withAnimation(.snappy(duration: 0.35, extraBounce: 0.05)) {
                        secondsString = newSeconds
                    }
                } else {
                    secondsString = newSeconds
                }
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
