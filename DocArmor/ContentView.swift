import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("DocArmor: Document Scanner")
                .font(.title2.bold())
            Text("Coming soon from Katafract.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
