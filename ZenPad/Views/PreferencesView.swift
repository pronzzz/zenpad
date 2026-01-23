import SwiftUI

struct PreferencesView: View {
    @StateObject private var preferences = Preferences.shared
    
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            EditorPreferencesView()
                .tabItem {
                    Label("Editor", systemImage: "text.alignleft")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralPreferencesView: View {
    @StateObject private var preferences = Preferences.shared
    
    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $preferences.appearanceMode) {
                    Text("System").tag(Preferences.AppearanceMode.system)
                    Text("Light").tag(Preferences.AppearanceMode.light)
                    Text("Dark").tag(Preferences.AppearanceMode.dark)
                }
                
                Toggle("Show welcome document on launch", isOn: $preferences.showWelcomeOnLaunch)
            }
            
            Section("Auto-Save") {
                Toggle("Enable auto-save", isOn: $preferences.autoSaveEnabled)
                
                if preferences.autoSaveEnabled {
                    Picker("Auto-save interval", selection: $preferences.autoSaveInterval) {
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                    }
                }
                
                Stepper(value: $preferences.maxVersions, in: 10...100, step: 10) {
                    Text("Keep last \(preferences.maxVersions) versions")
                }
            }
        }
        .padding()
    }
}

struct EditorPreferencesView: View {
    @StateObject private var preferences = Preferences.shared
    
    private let fontFamilies = ["SF Mono", "Menlo", "Monaco", "Courier New", "System"]
    private let fontSizes: [CGFloat] = [11, 12, 13, 14, 15, 16, 18, 20, 22, 24]
    
    var body: some View {
        Form {
            Section("Typography") {
                Picker("Font", selection: $preferences.fontFamily) {
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                
                Picker("Size", selection: $preferences.fontSize) {
                    ForEach(fontSizes, id: \.self) { size in
                        Text("\(Int(size)) pt").tag(size)
                    }
                }
                
                HStack {
                    Text("Line Height")
                    Slider(value: $preferences.lineHeight, in: 1.0...2.0, step: 0.1)
                    Text(String(format: "%.1f", preferences.lineHeight))
                        .frame(width: 30)
                }
            }
            
            Section("Preview") {
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(.custom(preferences.fontFamily, size: preferences.fontSize))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

#Preview {
    PreferencesView()
}
