import Foundation
import SwiftUI
import UserNotifications

struct ChallengeDay {
    let week: Int
    let intensity: Double
    let frequency: Int  // In minutes
}

class ChallengeManager: ObservableObject {
    @Published var isActive = false
    @Published var currentPushups = 0
    @Published var timeRemaining = "00:00"
    @Published var showBaseInput = false
    @Published var showMaxTestInput = false
    @Published var isTimerPaused = false
    @Published var challengeStarted: Bool = UserDefaults.standard.bool(forKey: "challengeStarted") {
        didSet {
            UserDefaults.standard.set(challengeStarted, forKey: "challengeStarted")
        }
    }
    @Published var showWelcomeScreen = true
    @Published var showDoneForToday: Bool = UserDefaults.standard.bool(forKey: "showDoneForToday") {
        didSet {
            UserDefaults.standard.set(showDoneForToday, forKey: "showDoneForToday")
        }
    }
    @Published var showNextDayScreen = false
    @Published var showChallengeCompleted = false
    @Published var showProgressScreen = false
    @Published var showStopWarning = false
    @Published var basePushups: Int = UserDefaults.standard.integer(forKey: "basePushups") {
        didSet {
            UserDefaults.standard.set(basePushups, forKey: "basePushups")
            if basePushups > 0 && !showMaxTestInput {
                calculateDailyPushups()
            }
        }
    }
    @Published var dailyPushupTotals: [Date: Int] = [:] {
        didSet {
            let stringKeyedDict = dailyPushupTotals.mapKeys { $0.ISO8601Format() }
            UserDefaults.standard.set(stringKeyedDict, forKey: "dailyPushupTotals")
        }
    }
    @Published var maxTestCounted: Bool = UserDefaults.standard.bool(forKey: "maxTestCounted") {
        didSet {
            UserDefaults.standard.set(maxTestCounted, forKey: "maxTestCounted")
        }
    }
    @Published var lastUpdatedDay: Date? = UserDefaults.standard.object(forKey: "lastUpdatedDay") as? Date {
        didSet {
            UserDefaults.standard.set(lastUpdatedDay, forKey: "lastUpdatedDay")
        }
    }
    
    private var timer: Timer?
    private var midnightTimer: Timer?
    public var currentFrequency: Int = UserDefaults.standard.integer(forKey: "currentFrequency") {
        didSet {
            UserDefaults.standard.set(currentFrequency, forKey: "currentFrequency")
        }
    }
    private var timeRemainingSeconds: Int = UserDefaults.standard.integer(forKey: "timeRemainingSeconds") {
        didSet {
            UserDefaults.standard.set(timeRemainingSeconds, forKey: "timeRemainingSeconds")
        }
    }
    
    private let schedule: [[ChallengeDay]] = [
        [
            ChallengeDay(week: 1, intensity: 0.3, frequency: 60),
            ChallengeDay(week: 1, intensity: 0.5, frequency: 60),
            ChallengeDay(week: 1, intensity: 0.6, frequency: 45),
            ChallengeDay(week: 1, intensity: 0.25, frequency: 60),
            ChallengeDay(week: 1, intensity: 0.45, frequency: 30),
            ChallengeDay(week: 1, intensity: 0.4, frequency: 60),
            ChallengeDay(week: 1, intensity: 0.2, frequency: 90),
        ],
        [
            ChallengeDay(week: 2, intensity: 0.35, frequency: 45),
            ChallengeDay(week: 2, intensity: 0.55, frequency: 20),
            ChallengeDay(week: 2, intensity: 0.3, frequency: 15),
            ChallengeDay(week: 2, intensity: 0.65, frequency: 60),
            ChallengeDay(week: 2, intensity: 0.35, frequency: 60),
            ChallengeDay(week: 2, intensity: 0.45, frequency: 60),
            ChallengeDay(week: 2, intensity: 0.25, frequency: 120),
        ]
    ]
    
    var currentWeek: Int {
        guard let startDate = UserDefaults.standard.object(forKey: "startDate") as? Date else {
            return 1
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min((daysSinceStart / 7) + 1, 2)
    }
    
    var currentDayIndex: Int {
        guard let startDate = UserDefaults.standard.object(forKey: "startDate") as? Date else {
            return 0
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return daysSinceStart < 14 ? min(daysSinceStart % 7, 6) : 6
    }
    
    var isChallengeCompleted: Bool {
        guard let startDate = UserDefaults.standard.object(forKey: "startDate") as? Date else {
            return false
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return daysSinceStart >= 14
    }
    
    init() {
        if let storedDict = UserDefaults.standard.dictionary(forKey: "dailyPushupTotals") as? [String: Int] {
            dailyPushupTotals = storedDict.mapKeys { ISO8601DateFormatter().date(from: $0) ?? Date() }
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        if UserDefaults.standard.object(forKey: "startDate") == nil && basePushups == 0 {
            showWelcomeScreen = true
            showMaxTestInput = false
        } else if basePushups > 0 {
            showWelcomeScreen = false
            showMaxTestInput = false
            updateChallengeForNewDay()
            if isChallengeCompleted {
                showChallengeCompleted = true
            } else if isRestrictedTime() {
                showDoneForToday = true
                scheduleResumeAt9AM()
            }
        } else {
            showMaxTestInput = true
            showWelcomeScreen = false
        }
        
        if isActive && !isTimerPaused && !isRestrictedTime() {
            startTimer()
        }
    }
    
    func startChallenge() {
        if UserDefaults.standard.object(forKey: "startDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "startDate")
        }
        
        if basePushups == 0 {
            showMaxTestInput = true
            showWelcomeScreen = false
            return
        }
        
        if isRestrictedTime() {
            showDoneForToday = true
            scheduleResumeAt9AM()
            return
        }
        
        if !isChallengeCompleted {
            challengeStarted = true
            updateChallengeForNewDay()
            if !showDoneForToday {
                setupDailyChallenge()
            }
        } else {
            showChallengeCompleted = true
        }
    }
    
    func setupDailyChallenge() {
        if isRestrictedTime() {
            timer?.invalidate()
            timer = nil
            isActive = false
            showDoneForToday = true
            scheduleResumeAt9AM()
            return
        }
        
        timer?.invalidate()
        timer = nil
        
        if isChallengeCompleted {
            showChallengeCompleted = true
            isActive = false
            showNextDayScreen = false
            showDoneForToday = false
            return
        }
        
        calculateDailyPushups()
        startTimer()
        isActive = true
        showNextDayScreen = false
    }
    
    func calculateDailyPushups() {
        let daySchedule = schedule[currentWeek - 1][currentDayIndex]
        if currentDayIndex == 0 && !maxTestCounted {
            currentPushups = basePushups
            currentFrequency = daySchedule.frequency
        } else {
            currentPushups = max(1, Int(Double(basePushups) * daySchedule.intensity))
            currentFrequency = daySchedule.frequency
        }
        lastUpdatedDay = Calendar.current.startOfDay(for: Date())
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = nil
        
        timeRemainingSeconds = currentFrequency * 60
        updateTimeDisplay()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self, !self.isTimerPaused else { return }
                
                let now = Date()
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: now)
                let minute = calendar.component(.minute, from: now)
                
                if hour == 0 && minute == 0 {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.isActive = false
                    self.showDoneForToday = true
                    self.showNextDayScreen = false
                    self.scheduleResumeAt9AM()
                    return
                }
                
                self.timeRemainingSeconds -= 1
                self.updateTimeDisplay()
                
                if self.timeRemainingSeconds <= 0 {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.showAlert()
                    self.restartTimer()
                }
            }
            
            if let timer = self.timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
        
        isTimerPaused = false
    }
    
    func pauseTimer() {
        isTimerPaused = true
    }
    
    func resumeTimer() {
        isTimerPaused = false
    }
    
    func restartTimer() {
        timer?.invalidate()
        timer = nil
        
        timeRemainingSeconds = currentFrequency * 60
        startTimer()
    }
    
    private func updateTimeDisplay() {
        let minutes = (timeRemainingSeconds % 3600) / 60
        let seconds = timeRemainingSeconds % 60
        timeRemaining = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func showAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Pushup Time! 💪"
        content.body = "Do \(currentPushups) pushups now!"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Pushup Time! 💪"
        alert.informativeText = "Do \(currentPushups) pushups now!"
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Skip")
        
        let response = alert.runModal()
        let today = Calendar.current.startOfDay(for: Date())
        
        if response == .alertFirstButtonReturn {
            dailyPushupTotals[today] = (dailyPushupTotals[today] ?? 0) + currentPushups
        }
    }
    
    func saveMaxTestPushups() {
        if !maxTestCounted {
            let today = Calendar.current.startOfDay(for: Date())
            dailyPushupTotals[today] = (dailyPushupTotals[today] ?? 0) + basePushups
            maxTestCounted = true
            challengeStarted = true
            calculateDailyPushups()
        }
    }
    
    func doneForToday() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isTimerPaused = false
        timeRemainingSeconds = currentFrequency * 60
        updateTimeDisplay()
        showDoneForToday = true
        scheduleResumeAt9AM()
    }
    
    func updateChallengeForNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if isChallengeCompleted {
            showChallengeCompleted = true
            return
        }
        
        if lastUpdatedDay == nil || !Calendar.current.isDate(lastUpdatedDay!, inSameDayAs: today) {
            lastUpdatedDay = today
            calculateDailyPushups()
        }
        
        if !showDoneForToday {
            showNextDayScreen = true
        }
    }
    
    public func isRestrictedTime() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        return hour >= 0 && hour < 9
    }
    
    private func scheduleResumeAt9AM() {
            midnightTimer?.invalidate()
            midnightTimer = nil
            
            let now = Date()
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "CET")! // Explicitly set to CET
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 9
            components.minute = 0
            components.second = 0
            
            guard let resumeTime = calendar.date(from: components) else {
                print("Error: Failed to calculate resume time.")
                return
            }
            
            let timeInterval = resumeTime.timeIntervalSince(now)
            print("Scheduling resume at \(resumeTime) (in \(timeInterval) seconds from \(now))")
            
            if timeInterval < 0 {
                // If 9 AM has passed today, schedule for tomorrow at 9 AM
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
                    print("Error: Failed to calculate tomorrow's date.")
                    return
                }
                components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = 9
                components.minute = 0
                components.second = 0
                guard let nextResumeTime = calendar.date(from: components) else {
                    print("Error: Failed to calculate next day's resume time.")
                    return
                }
                let adjustedTimeInterval = nextResumeTime.timeIntervalSince(now)
                print("Scheduling for tomorrow at \(nextResumeTime) (in \(adjustedTimeInterval) seconds)")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.midnightTimer = Timer.scheduledTimer(withTimeInterval: adjustedTimeInterval, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        print("Timer fired at \(Date()) - Starting next day's challenge.")
                        self.showDoneForToday = false
                        self.showNextDayScreen = false
                        self.updateChallengeForNewDay()
                        self.setupDailyChallenge()
                    }
                    if let timer = self.midnightTimer {
                        RunLoop.current.add(timer, forMode: .common)
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        print("Timer fired at \(Date()) - Starting next day's challenge.")
                        self.showDoneForToday = false
                        self.showNextDayScreen = false
                        self.updateChallengeForNewDay()
                        self.setupDailyChallenge()
                    }
                    if let timer = self.midnightTimer {
                        RunLoop.current.add(timer, forMode: .common)
                    }
                }
            }
        }
    
    func stopChallenge() {
        timer?.invalidate()
        timer = nil
        midnightTimer?.invalidate()
        midnightTimer = nil
        resetChallenge()
        showStopWarning = false
        showProgressScreen = false
    }
    
    func resetChallenge() {
        isActive = false
        currentPushups = 0
        timeRemaining = "00:00"
        showBaseInput = false
        showMaxTestInput = true
        basePushups = 0
        dailyPushupTotals = [:]
        maxTestCounted = false
        showDoneForToday = false
        showNextDayScreen = false
        showChallengeCompleted = false
        lastUpdatedDay = nil
        challengeStarted = false
        UserDefaults.standard.removeObject(forKey: "startDate")
        UserDefaults.standard.removeObject(forKey: "dailyPushupTotals")
        UserDefaults.standard.removeObject(forKey: "maxTestCounted")
        UserDefaults.standard.removeObject(forKey: "currentFrequency")
        UserDefaults.standard.removeObject(forKey: "timeRemainingSeconds")
        UserDefaults.standard.removeObject(forKey: "showDoneForToday")
        UserDefaults.standard.removeObject(forKey: "lastUpdatedDay")
        UserDefaults.standard.removeObject(forKey: "basePushups")
        UserDefaults.standard.removeObject(forKey: "challengeStarted")
        showWelcomeScreen = true
    }
    
    func resetAndRestartChallenge() {
        resetChallenge()
        showWelcomeScreen = false
        showMaxTestInput = true
        showChallengeCompleted = false
    }
    
    func getProgressData() -> [(date: Date, pushups: Int)] {
        return dailyPushupTotals.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
}

extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
