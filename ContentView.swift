import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ChallengeManager()
    
    var body: some View {
        Group {
            if manager.showWelcomeScreen {
                WelcomeScreen(manager: manager)
            } else if manager.showMaxTestInput && !manager.challengeStarted {
                MaxTestInputView(manager: manager)
            } else if manager.showDoneForToday {
                DoneForTodayView(manager: manager)
            } else if manager.showNextDayScreen {
                NextDayView(manager: manager)
            } else if manager.showChallengeCompleted {
                ChallengeCompletedView(manager: manager)
            } else if manager.showProgressScreen {
                ProgressView(manager: manager)
            } else if manager.showStopWarning {
                StopWarningView(manager: manager)
            } else {
                ChallengeStatusView(manager: manager)
            }
        }
        .padding()
        .frame(width: 250, height: 300)
    }
}

struct WelcomeScreen: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Evil Russian Pushup Challenge")
                .font(.title2)
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
            
            Text("Transform your strength! 💪")
                .font(.body)
                .multilineTextAlignment(.center)
            
            Text("Prepare to double your pushup power by the end of this challenge.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Start Challenge") {
                manager.showWelcomeScreen = false
                manager.showMaxTestInput = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

struct MaxTestInputView: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Weekly Max Test\n Week \(manager.currentWeek)")
                .font(.title2.bold())
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
            
            Text("Do as many pushups as you can and enter the number below.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Enter your max pushups", value: $manager.basePushups, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .multilineTextAlignment(.center)

            Button("Save & Continue") {
                if UserDefaults.standard.object(forKey: "startDate") == nil {
                    UserDefaults.standard.set(Date(), forKey: "startDate")
                }
                manager.saveMaxTestPushups()
                manager.showMaxTestInput = false
                manager.setupDailyChallenge()
            }
            .disabled(manager.basePushups <= 0)
            .buttonStyle(.borderedProminent)
            .tint(manager.basePushups > 0 ? .green : .gray)
        }
        .padding()
    }
}

struct ChallengeStatusView: View {
    @ObservedObject var manager: ChallengeManager
    @State private var contentOffset: CGFloat = -20

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Spacer()
                Button("Quit") {
                    manager.showStopWarning = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .offset(y: -10)
            }

            VStack(spacing: 10) {
                Text("Week \(manager.currentWeek) - Day \(manager.currentDayIndex + 1)")
                    .font(.title3.bold())
                Text("Next Set: \(manager.currentPushups) pushups")
                    .font(.title2)
                Text("Next Alert In")
                    .font(.headline)
                Text(manager.timeRemaining)
                    .font(.system(.title, design: .monospaced))

                if manager.isActive {
                    if manager.isTimerPaused {
                        Button("Resume Timer") {
                            manager.resumeTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Button("Pause Timer") {
                            manager.pauseTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                    }
                    Button("Done for Today") {
                        manager.doneForToday()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                } else {
                    Button("Start Session") {
                        manager.startChallenge()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("View Progress") {
                    manager.showProgressScreen = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .offset(y: contentOffset)
        }
    }
}

struct DoneForTodayView: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Are you ready?")
                .font(.title2.bold())
                .foregroundColor(.green)
            
            Text("Time to start today's new challenge")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)

            Button("Start Challenge") {
                manager.showDoneForToday = false
                manager.setupDailyChallenge()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .offset(y: -10)
        .onAppear {
            manager.calculateDailyPushups()
        }
    }
}

struct NextDayView: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Ready for Day \(manager.currentDayIndex + 1)?")
                .font(.title2.bold())
                .foregroundColor(.blue)
            
            Text("Today: \(manager.currentPushups) pushups every \(manager.currentFrequency) minutes")
                .font(.body)
                .multilineTextAlignment(.center)
            
            Button("Start Training") {
                manager.setupDailyChallenge()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .onAppear {
            manager.calculateDailyPushups()
        }
    }
}

struct ChallengeCompletedView: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Challenge Completed!")
                .font(.title2.bold())
                .foregroundColor(.green)
            
            Text("Congratulations! You've completed the 14-day Evil Russian Pushup Challenge.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(manager.getProgressData(), id: \.date) { entry in
                        Text("\(entry.date, formatter: dateFormatter): \(entry.pushups) pushups")
                    }
                }
            }
            
            Button("Start Again") {
                manager.resetAndRestartChallenge()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .frame(width: 250, height: 300)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

struct ProgressView: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Pushup Progress")
                .font(.title2.bold())
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(manager.getProgressData(), id: \.date) { entry in
                        Text("\(entry.date, formatter: dateFormatter): \(entry.pushups) pushups")
                    }
                }
            }
            
            Button("Back") {
                manager.showProgressScreen = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
        }
        .padding()
        .frame(width: 250, height: 300)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

struct StopWarningView: View {
    @ObservedObject var manager: ChallengeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stop Training")
                .font(.title2.bold())
                .foregroundColor(.red)
            
            Text("This will reset all your progress. Are you sure?")
                .font(.body)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Yes") {
                    manager.stopChallenge()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button("No") {
                    manager.showStopWarning = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
            }
        }
        .padding()
        .frame(width: 250, height: 300)
    }
}

#Preview {
    ContentView()
}
