import Foundation
import SwiftUI

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
    @Published var showWelcomeScreen = true
    @Published var showRestScreen = false
    @Published var showDoneForToday: Bool = UserDefaults.standard.bool(forKey: "showDoneForToday") {
        didSet {
            UserDefaults.standard.set(showDoneForToday, forKey: "showDoneForToday")
        }
    }
    @Published var showNextDayScreen = false
    @Published var showChallengeCompleted = false
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
            ChallengeDay(week: 1, intensity: 0.3, frequency: 1),
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
        return min((daysSinceStart / 7) + 1, 2) // Cap at 2 weeks
    }
    
    var currentDayIndex: Int {
        guard let startDate = UserDefaults.standard.object(forKey: "startDate") as? Date else {
            return 0
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return daysSinceStart < 14 ? min(daysSinceStart % 7, 6) : 6 // Stop at day 14 (end of week 2)
    }
    
    var isChallengeCompleted: Bool {
        guard let startDate = UserDefaults.standard.object(forKey: "startDate") as? Date else {
            return false
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return daysSinceStart >= 14 // 14 days = 2 weeks
    }
    
    init() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            basePushups = 0
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
        
        if let storedDict = UserDefaults.standard.dictionary(forKey: "dailyPushupTotals") as? [String: Int] {
            dailyPushupTotals = storedDict.mapKeys { ISO8601DateFormatter().date(from: $0) ?? Date() }
        }
        
        if basePushups == 0 {
            showBaseInput = true
        } else {
            calculateDailyPushups()
            checkDayTransition()
            if isChallengeCompleted {
                showChallengeCompleted = true
            }
        }
        
        if isActive && !isTimerPaused {
            startTimer() // Resume timer if app was closed while active
        }
    }
    
    func startChallenge() {
        if UserDefaults.standard.object(forKey: "startDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "startDate")
        }
        
        if basePushups == 0 {
            showBaseInput = true
            return
        }
        
        if currentDayIndex == 0 && !maxTestCounted {
            showMaxTestInput = true
        } else if !isChallengeCompleted {
            checkDayTransition()
            if !showDoneForToday {
                setupDailyChallenge()
            }
        } else {
            showChallengeCompleted = true
        }
    }
    
    func setupDailyChallenge() {
        timer?.invalidate()
        timer = nil
        
        if isChallengeCompleted {
            showChallengeCompleted = true
            return
        }
        
        calculateDailyPushups()
        startTimer()
        isActive = true
        showNextDayScreen = false
    }
    
    private func calculateDailyPushups() {
        let daySchedule = schedule[currentWeek - 1][currentDayIndex]
        currentPushups = max(1, Int(Double(basePushups) * daySchedule.intensity))
        currentFrequency = daySchedule.frequency
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
        let alert = NSAlert()
        alert.messageText = "Pushup Time! 💪"
        alert.informativeText = "Do \(currentPushups) pushups now!"
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Skip")
        
        let notification = NSUserNotification()
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
        
        let response = alert.runModal()
        let today = Calendar.current.startOfDay(for: Date())
        
        if response == .alertFirstButtonReturn { // "Done" clicked
            dailyPushupTotals[today] = (dailyPushupTotals[today] ?? 0) + currentPushups
        }
    }
    
    func saveMaxTestPushups() {
        if !maxTestCounted {
            let today = Calendar.current.startOfDay(for: Date())
            dailyPushupTotals[today] = (dailyPushupTotals[today] ?? 0) + basePushups
            maxTestCounted = true
        }
    }
    
    func doneForToday() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isTimerPaused = false
        timeRemaining = "00:00"
        showDoneForToday = true
        scheduleNextDayResume()
    }
    
    private func scheduleNextDayResume() {
        midnightTimer?.invalidate()
        midnightTimer = nil
        
        let now = Date()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return }
        
        let tomorrowMidnight = calendar.startOfDay(for: tomorrow)
        let timeInterval = tomorrowMidnight.timeIntervalSinceNow
        
        DispatchQueue.main.async { [weak self] in
            self?.midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.showDoneForToday = false
                self.showNextDayScreen = true
                self.checkDayTransition()
            }
            if let timer = self?.midnightTimer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    private func checkDayTransition() {
        let today = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour], from: now)
        
        if isChallengeCompleted {
            showChallengeCompleted = true
            return
        }
        
        if let lastDay = dailyPushupTotals.keys.max(), lastDay < today {
            if showDoneForToday {
                showDoneForToday = false
                showNextDayScreen = true
            } else if let hour = components.hour, hour >= 0 && hour < 9 {
                // Show "Done for Today" only between midnight and 9 am
                showDoneForToday = true
                scheduleNextDayResume()
            } else {
                showNextDayScreen = true
                isActive = false
            }
        }
    }
    
    func stopChallenge() {
        timer?.invalidate()
        timer = nil
        midnightTimer?.invalidate()
        midnightTimer = nil
        resetChallenge()
    }
    
    deinit {
        timer?.invalidate()
        midnightTimer?.invalidate()
    }
    
    func resetChallenge() {
        isActive = false
        currentPushups = 0
        timeRemaining = "00:00"
        showBaseInput = false
        showMaxTestInput = false
        basePushups = 0
        dailyPushupTotals = [:]
        maxTestCounted = false
        showDoneForToday = false
        showNextDayScreen = false
        showChallengeCompleted = false
        UserDefaults.standard.removeObject(forKey: "startDate")
        UserDefaults.standard.removeObject(forKey: "dailyPushupTotals")
        UserDefaults.standard.removeObject(forKey: "maxTestCounted")
        UserDefaults.standard.removeObject(forKey: "currentFrequency")
        UserDefaults.standard.removeObject(forKey: "timeRemainingSeconds")
        UserDefaults.standard.removeObject(forKey: "showDoneForToday")
        showWelcomeScreen = true
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
