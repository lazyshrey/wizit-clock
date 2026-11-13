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
        updateTime()
        // Update at 10Hz for super crisp second transitions with zero lag
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTime()
            }
    }
    
    public func updateTime() {
        let now = Date()
        currentDate = now
        
        let settings = AppSettings.shared
        
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        if settings.is24Hour {
            formatter.dateFormat = "HH"
            hoursString = formatter.string(from: now)
            amPmString = ""
        } else {
            formatter.dateFormat = "h"
            hoursString = formatter.string(from: now)
            formatter.dateFormat = "a"
            amPmString = formatter.string(from: now).uppercased()
        }
        
        formatter.dateFormat = "mm"
        minutesString = formatter.string(from: now)
        
        formatter.dateFormat = "ss"
        secondsString = formatter.string(from: now)
        
        formatter.dateFormat = "EEEE"
        weekdayString = formatter.string(from: now)
        
        formatter.dateFormat = "MMMM d"
        dateFormattedString = formatter.string(from: now)
    }
}
