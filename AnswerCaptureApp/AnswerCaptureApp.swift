import SwiftUI

@main
struct AnswerCaptureApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .task { await model.load() }
        }
    }
}
