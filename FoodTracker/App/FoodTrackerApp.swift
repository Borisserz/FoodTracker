import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn
import AppTrackingTransparency

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

@Model final class AIChatSession {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var messages: [AIChatMessage] = []

    init(title: String = "New Chat", date: Date = Date(), messages: [AIChatMessage] = []) {
        self.title = title
        self.date = date
        self.messages = messages
    }
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let isUser: Bool
    var text: String
    var isAnimating: Bool = false

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

@main
struct FoodTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Migrated from @StateObject/ObservableObject to @Observable per system-rules and swiftui-pro
    @State private var versionManager = VersionManager.shared

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
            .onAppear {
                TrackingManager.shared.track(.appOpened(source: "launch"))
            }
        }
    }

    @MainActor
    private func setupDependencies() async {
        do {
            let schema = Schema([
                User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, DailySummary.self, AIChatSession.self, ShoppingItem.self,
                WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self
            ])
            
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.borisdev.WorkoutTracker") ?? FileManager.default.temporaryDirectory
            let dbURL = groupURL.appendingPathComponent("FoodDatabase.sqlite")
            
            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: dbURL,
                cloudKitDatabase: .private("iCloud.com.borisdev.FoodTracker")
            )

            let container: ModelContainer
            do {
                container = try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                print("⚠️ CloudKit init failed, falling back to local: \(error)")
                let localConfig = ModelConfiguration(schema: schema, url: dbURL, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
            }

            let di = DIContainer(modelContainer: container)
            self.diContainer = di
            
            do {
                _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
            } catch {
                print("⚠️ Anonymous auth failed: \(error)")
            }

            await RemoteConfigManager.shared.fetchCloudValues()
            await versionManager.checkForUpdates()
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
    @AppStorage("hasCompletedOnboarding_v1") private var hasCompletedOnboarding = false

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
        return TabView(selection: $state.selectedTab) {
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

            AICoachDashboardView(selectedDate: Date())
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(4)
                
            GoalsTabView()
                .tabItem { Label("Goals", systemImage: "target") }
                .tag(5)
        }
        .tint(themeManager.current.primaryAccent)
        .onAppear {
            initializeUserIfNeeded()

            if let user = users.first, user.isHealthKitEnabled {
                Task {
                    try? await HealthKitManager.shared.requestAuthorization()
                }
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                _ = await ATTrackingManager.requestTrackingAuthorization()
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
        let bmr = 10.0 * Double(metrics.weight) + 6.25 * Double(metrics.height) - 5.0 * Double(metrics.age) + 5.0
        
        var multiplier = 1.2
        switch metrics.activityLevel {
        case .none: multiplier = 1.2
        case .office: multiplier = 1.2
        case .light: multiplier = 1.375
        case .active: multiplier = 1.55
        case .beast: multiplier = 1.725
        }
        
        var tdee = bmr * multiplier
        
        if metrics.goal == "Lose Weight" {
            tdee -= 500
        } else if metrics.goal == "Build Muscle" {
            tdee += 300
        }
        
        let cals = Int(tdee)

        if let existingUser = users.first {
            existingUser.age = metrics.age
            existingUser.height = Double(metrics.height)
            existingUser.weight = Double(metrics.weight)
            existingUser.dailyCaloriesGoal = cals
        } else {
            let newUser = User(
                name: "Champion",
                weight: Double(metrics.weight),
                height: Double(metrics.height),
                age: metrics.age,
                gender: "Male"
            )
            newUser.dailyCaloriesGoal = cals
            context.insert(newUser)
        }
        try? context.save()
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
    // Without this the fancy onboarding re-appears on every cold launch.
    @AppStorage("hasCompletedInitialOnboarding_v1") private var hasCompletedInitialOnboarding = false

    @State private var currentStep: AppLaunchStep

    init() {
        // Initialize step from persisted flag so we don't force the account screen every launch
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedInitialOnboarding_v1")
        _currentStep = State(initialValue: completed ? .mainApp : .screen1)
    }

    var body: some View {
        ZStack {
            switch currentStep {
            case .screen1:
                // ЭКРАН 1 ИЗ МОНЕТКИ (3D-еда и вход)
                OnboardingView(onSuccess: {
                    hasCompletedInitialOnboarding = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .mainApp
                    }
                })
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

            case .mainApp:
                // Переход в главное приложение
                ContentView() // Главный экран FoodTracker
                    .transition(.opacity)
            }
        }
    }
}
