import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppCheck.setAppCheckProviderFactory(AppCheckFactory())
        FirebaseApp.configure()
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct FoodTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Migrated from @StateObject/ObservableObject to @Observable per system-rules and swiftui-pro
    @State private var versionManager = VersionManager.shared
    @State private var geminiClient = GeminiProxyClient.shared

    @State private var diContainer: DIContainer?
    @State private var databaseLoadError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if versionManager.updateRequirement == .hardUpdate {
                    VStack {
                        Text("Update Required")
                            .font(.title).bold()
                        Text("Please update to the latest version to continue.")
                            .multilineTextAlignment(.center).padding()
                        Button("Update Now") { AppReviewManager.openAppStoreReview() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if let error = databaseLoadError {
                    Text("Database Error: \(error.localizedDescription)")
                } else if let di = diContainer {
                    RootLaunchView()
                        .modelContainer(di.modelContainer)
                        .environment(di)
                        .environment(di.appState)
                        .environment(di.authManager)
                        .environment(ThemeManager.shared)
                        .preferredColorScheme(.light)
                } else {
                    ProgressView("Initializing...")
                }
            }
            .task {
                await setupDependencies()
            }
            .alert("Update Available", isPresented: Binding(
                get: { versionManager.updateRequirement == .softUpdate && !versionManager.hasDismissedSoftUpdate },
                set: { if !$0 { versionManager.hasDismissedSoftUpdate = true } }
            )) {
                Button("Update Now") { AppReviewManager.openAppStoreReview() }
                Button("Later", role: .cancel) { versionManager.hasDismissedSoftUpdate = true }
            } message: {
                Text("A new version of FoodTracker is available.")
            }
            .alert("AI Limit Reached", isPresented: Binding(
                get: { geminiClient.rateLimitAlertMessage != nil },
                set: { if !$0 { geminiClient.rateLimitAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { geminiClient.rateLimitAlertMessage = nil }
            } message: {
                Text(geminiClient.rateLimitAlertMessage ?? "")
            }
            .onAppear {
                TrackingManager.shared.track(.appOpened(source: "launch"))
            }
        }
    }

    @MainActor
    private func setupDependencies() async {
        print("🚀 [setupDependencies] Starting initialization...")
        do {
            let schema = Schema([
                User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, ActivityLog.self, DailySummary.self, AIChatSession.self, ShoppingItem.self,
                WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self
            ])
            
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.borisdev.WorkoutTracker") ?? FileManager.default.temporaryDirectory
            let dbURL = groupURL.appendingPathComponent("FoodDatabase.sqlite")
            print("🚀 [setupDependencies] dbURL resolved: \(dbURL)")
            
            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: dbURL,
                cloudKitDatabase: .private("iCloud.com.borisdev.FoodTracker2026")
            )

            let container: ModelContainer
            do {
                print("🚀 [setupDependencies] Initializing ModelContainer with CloudKit...")
                container = try ModelContainer(for: schema, configurations: [cloudConfig])
                print("🚀 [setupDependencies] ModelContainer successfully initialized with CloudKit!")
            } catch {
                print("⚠️ CloudKit init failed, falling back to local: \(error)")
                let localConfig = ModelConfiguration(schema: schema, url: dbURL, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
                print("🚀 [setupDependencies] ModelContainer successfully initialized on Local Storage fallback!")
            }

            let di = DIContainer(modelContainer: container)
            self.diContainer = di
            print("🚀 [setupDependencies] diContainer assigned to state. Re-rendering UI...")
            
            do {
                print("🚀 [setupDependencies] Attempting Anonymous Firebase sign-in...")
                _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
                print("🚀 [setupDependencies] Firebase Sign-in Complete!")
            } catch {
                print("⚠️ Anonymous auth failed: \(error)")
            }

            print("🚀 [setupDependencies] Fetching Remote Config values...")
            await RemoteConfigManager.shared.fetchCloudValues()
            print("🚀 [setupDependencies] Remote Config Fetch Complete!")
            
            print("🚀 [setupDependencies] Checking for updates...")
            await VersionManager.shared.checkVersion()
            print("🚀 [setupDependencies] Update checks complete!")
        } catch {
            self.databaseLoadError = error
            TrackingManager.shared.recordError(error: error)
            print("❌ SwiftData Init Failed: \(error)")
        }
    }
}

struct IdentifiableString: Identifiable, Hashable {
    let value: String
    
    var id: String { value }  // Stable identity based on the wrapped value.
    // Previously used a fresh UUID() every time the struct was created,
    // which caused .sheet(item:) / .fullScreenCover(item:) to repeatedly
    // dismiss and re-present the sheet because SwiftUI saw "different" items.
}

struct ContentView: View {
    @Environment(AppStateManager.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @AppStorage("hasCompletedOnboarding_v2") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainAppView
            } else {
                RootOnboardingView { metrics in
                    completeOnboarding(metrics: metrics)
                }
            }
        }
    }

    private var mainAppView: some View {
        @Bindable var state = appState
        return ZStack {
            TabView(selection: $state.selectedTab) {
                HomeDashboardView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                FoodsDashboardView()
                    .tabItem { Label("Foods", systemImage: "leaf.arrow.circlepath") }
                    .tag(1)

                AIChefStudioView()
                    .tabItem { Label("AI Chef", systemImage: "frying.pan.fill") }
                    .tag(2)

                AnalyticsTabView()
                    .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                    .tag(3)

                MoreTabView()
                    .tabItem { Label("AI Coach", systemImage: "sparkles") }
                    .tag(4)
            }
            .tint(themeManager.current.primaryAccent)
            
            // In-App Interactive Spotlight Tutorial
            SpotlightOverlayView()
        }
        .coordinateSpace(name: "SpotlightCoordinateSpace")
        .onPreferenceChange(SpotlightFramePreferenceKey.self) { frames in
            SpotlightTourManager.shared.targetFrames = frames
        }
        .onOpenURL { url in
            _ = appState.handleWidgetURL(url)
        }
        .onChange(of: appState.requestedWidgetAction) { _, newAction in
            if newAction == "metabolic" || newAction == "analytics" {
                appState.requestedWidgetAction = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.requestedWidgetAction == "shopping" },
            set: { if !$0 { appState.requestedWidgetAction = nil } }
        )) {
            NavigationStack {
                ShoppingListView()
            }
        }
        .onAppear {
            initializeUserIfNeeded()
            SpotlightTourManager.shared.startTourIfNeeded()

            if let user = users.first, user.isHealthKitEnabled {
                Task {
                    try? await HealthKitManager.shared.requestAuthorization()
                }
            }
        }
    }

    private func initializeUserIfNeeded() {
        if users.isEmpty {
            let defaultUser = User(name: "Alex", weight: 75.0, height: 180.0, age: 28, gender: "Male")
            context.insert(defaultUser)
            try? context.save()
        }
    }
    
    private func completeOnboarding(metrics: OnboardingMetrics) {
        OnboardingPersistence.save(metrics: metrics, existingUser: users.first, in: context)

        // Track onboarding completion
        TrackingManager.shared.track(.onboardingCompleted(goal: metrics.goal, diet: "Standard"))

        hasCompletedOnboarding = true
    }
}
enum AppLaunchStep {
    case screen1
    case mainApp
}

struct RootLaunchView: View {
    @Environment(AppStateManager.self) private var appState

    // Persist whether user has already completed the initial Monetka/account entry screen.
    // Observing @AppStorage directly lets account reset transition immediately without a cold restart.
    @AppStorage("hasCompletedInitialOnboarding_v2") private var hasCompletedInitialOnboarding = false

    var body: some View {
        ZStack {
            if !hasCompletedInitialOnboarding {
                OnboardingView(onSuccess: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        hasCompletedInitialOnboarding = true
                    }
                })
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
    }
}
