import SwiftUI

@main
struct WorkPhotoOrganizerApp: App {
    @StateObject private var store = PhotoOrganizerStore()
    @StateObject private var intentRouter = AppIntentRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(intentRouter)
        }
    }
}
