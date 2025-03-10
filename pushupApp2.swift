import SwiftUI

@main
struct PushupChallengeApp: App {
    var body: some Scene {
        MenuBarExtra("Pushup Challenge", systemImage: "figure.strengthtraining.traditional") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
