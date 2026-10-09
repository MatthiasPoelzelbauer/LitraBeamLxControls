import ServiceManagement
import SwiftUI

@main
struct LitraApp: App {
    // State is used directly because the @State macro plugin ships only with Xcode, not the Command Line Tools.
    private let lightState = State(initialValue: LightState())
    private var state: LightState { lightState.wrappedValue }

    init() {
        try? SMAppService.mainApp.register()
    }

    var body: some Scene {
        // The menu bar item is only shown while the light is connected.
        MenuBarExtra(
            "Litra",
            systemImage: state.frontOn || state.backOn ? "sun.max.fill" : "sun.max",
            isInserted: Binding(get: { state.device.isConnected }, set: { _ in })
        ) {
            MenuView(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}
