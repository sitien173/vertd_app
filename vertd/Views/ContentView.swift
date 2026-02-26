import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            UploadView()
                .tabItem {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }

            JobsListView()
                .tabItem {
                    Label("Jobs", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
