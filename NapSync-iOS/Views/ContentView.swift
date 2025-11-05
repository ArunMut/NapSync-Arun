import SwiftUI
import NapSyncShared

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
    @EnvironmentObject var coreDataManager: CoreDataManager
    @EnvironmentObject var mlModelService: MLModelService
    
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Main nap interface
            NavigationView {
                HomeView(viewModel: homeViewModel)
                    .environmentObject(healthKitManager)
                    .environmentObject(watchConnectivityManager)
                    .environmentObject(mlModelService)
            }
            .tabItem {
                Label("Nap", systemImage: "moon.zzz")
            }
            .tag(0)
            
            // History Tab - Past nap sessions
            NavigationView {
                NapHistoryView()
                    .environmentObject(coreDataManager)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)

            // Analytics Tab - AI powered trends and metrics
            NavigationView {
                AnalyticsView()
                    .environmentObject(mlModelService)
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }
            .tag(2)
            
            // Settings Tab
            NavigationView {
                SettingsView()
                    .environmentObject(healthKitManager)
                    .environmentObject(watchConnectivityManager)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .onAppear {
            setupEnvironment()
        }
    }
    
    private func setupEnvironment() {
        // Setup any additional environment configuration
        homeViewModel.setup(
            healthKit: healthKitManager,
            watchConnectivity: watchConnectivityManager,
            mlService: mlModelService
        )
    }
}

// MARK: - Supporting Views

struct NapHistoryView: View {
    @EnvironmentObject var coreDataManager: CoreDataManager
    
    var body: some View {
        VStack {
            Text("Nap History")
                .font(.largeTitle)
                .padding()
            
            Text("Your past nap sessions will appear here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .navigationTitle("History")
    }
}

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
    
    var body: some View {
        List {
            Section("Health & Privacy") {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("HealthKit Access")
                    Spacer()
                    if healthKitManager.isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Enable") {
                            healthKitManager.requestAuthorization()
                        }
                    }
                }
            }
            
            Section("Apple Watch") {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundColor(.blue)
                    Text("Watch Connection")
                    Spacer()
                    if watchConnectivityManager.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("Disconnected")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section("About") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(WatchConnectivityManager())
        .environmentObject(CoreDataManager())
        .environmentObject(MLModelService.shared)
}