import SwiftUI

/// Root auth-gate router. Switches between the lock screen and the main vault
/// based on `AuthService.state`. Also wires auto-lock activity tracking.
struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AutoLockService.self) private var autoLock

    var body: some View {
        Group {
            switch auth.state {
            case .locked, .authenticating:
                LockScreenView()
                    .transition(.opacity)
            case .unlocked:
                HomeView()
                    .transition(.opacity)
            }
        }
        // Animate on every state transition (locked ↔ authenticating ↔ unlocked),
        // not just the Bool flips, by using the Equatable enum value directly.
        .animation(.easeInOut(duration: 0.25), value: auth.state)
        .onChange(of: auth.state) { _, newState in
            if newState == .unlocked {
                autoLock.recordActivity()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
        .environment(AutoLockService(authService: AuthService()))
}
