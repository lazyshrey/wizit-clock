import SwiftUI
import Combine

@MainActor
public final class TimeManager: ObservableObject {
    public static let shared = TimeManager()
    
    @Published public var currentDate: Date = Date()
    @Published public var hoursString: String = "12"
    @Published public var minutesString: String = "00"
    @Published public var secondsString: String = "00"
    @Published public var amPmString: String = "AM"
    @Published public var weekdayString: String = "Monday"
    @Published public var dateFormattedString: String = "Jan 1"
    
    private var timerCancellable: AnyCancellable?
    
    private let calendar = Calendar.current
    
    private init() {
        updateTime(animated: false)
        // Update at 10Hz for super crisp second transitions with zero lag
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
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
        
        if settings.is24Hour {
            formatter.dateFormat = "HH"
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
        
        formatter.dateFormat = "EEEE"
        weekdayString = formatter.string(from: now)
        
        formatter.dateFormat = "MMMM d"
        dateFormattedString = formatter.string(from: now)
    }
}
