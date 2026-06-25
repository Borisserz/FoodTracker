import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn
import UserNotifications
import WidgetKit

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
    @Environment(\.scenePhase) var scenePhase

    // Migrated from @StateObject/ObservableObject to @Observable per system-rules and swiftui-pro
    @State private var versionManager = VersionManager.shared

    @State private var diContainer: DIContainer?
    @State private var databaseLoadError: Error?
    @State private var recipeDataLoader: RecipeDataLoader?
    @State private var academyDataLoader: AcademyDataLoader?

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
                } else if let di = diContainer, let recipeLoader = recipeDataLoader, let academyLoader = academyDataLoader {
                    RootLaunchView()
                        .modelContainer(di.modelContainer)
                        .environment(di)
                        .environment(di.appState)
                        .environment(di.authManager)
                        .environment(ThemeManager.shared)
                        .environment(recipeLoader)
                        .environment(academyLoader)
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    WidgetCenter.shared.reloadAllTimelines()
                } else if newPhase == .active {
                    PromoManager.shared.checkAndShowWidgetPromo()
                }
            }
        }
    }

    @MainActor
    private func setupDependencies() async {
        print("🚀 [setupDependencies] Starting initialization...")
        do {
            let container = SharedModelContainer.shared.container
            print("🚀 [setupDependencies] ModelContainer successfully initialized via SharedModelContainer!")

            let di = DIContainer(modelContainer: container)
            self.recipeDataLoader = RecipeDataLoader()
            self.academyDataLoader = AcademyDataLoader()
            self.diContainer = di
            print("🚀 [setupDependencies] diContainer assigned to state. Re-rendering UI...")
            
            do {
                print("🚀 [setupDependencies] Attempting Anonymous Firebase sign-in...")
                _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
                print("🚀 [setupDependencies] Firebase Sign-in Complete!")
                
                // Trigger auto-seeding if Firestore database is empty
                DispatchQueue.main.async {
                    FirebaseUploader.shared.seedDatabaseIfNeeded()
                    FirebaseUploader.shared.uploadNewRecipesFromJSON()
                }
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
    
    @State private var promoManager = PromoManager.shared

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
        .sheet(isPresented: $promoManager.showWidgetPromo) {
            WidgetPromoView()
                .presentationDetents([.fraction(0.85)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .interactiveDismissDisabled(true) // Force users to interact with buttons
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

            MoreTabView()
                .tabItem { Label("AI Coach", systemImage: "sparkles") }
                .tag(4)
        }
        .tint(themeManager.current.primaryAccent)
        .overlay {
            // Floating pill visible on every tab during background plan generation
            GenerationStatusPill()
        }
        .onAppear {
            initializeUserIfNeeded()

            if let user = users.first, user.isHealthKitEnabled {
                Task {
                    try? await HealthKitManager.shared.requestAuthorization()
                }
            }
        }
        .onChange(of: users) { _, newUsers in
            if newUsers.isEmpty {
                initializeUserIfNeeded()
            }
        }
    }

    private func initializeUserIfNeeded() {
        if users.isEmpty {
            let defaultUser = User(name: "Alex", weight: 75.0, height: 180.0, age: 28, gender: "Male")
            defaultUser.dailyCaloriesGoal = 2000
            defaultUser.applyDietBreakdown(fatPercent: 30, proteinPercent: 30, carbsPercent: 40, dietKey: "balanced")
            context.insert(defaultUser)
            try? context.save()
        } else if let user = users.first {
            if user.targetCarbs <= 0 && user.dailyCaloriesGoal > 0 {
                user.applyDietBreakdown(fatPercent: 30, proteinPercent: 30, carbsPercent: 40, dietKey: user.activeDietKey.isEmpty ? "balanced" : user.activeDietKey)
                try? context.save()
            }
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
            existingUser.applyDietBreakdown(fatPercent: 30, proteinPercent: 30, carbsPercent: 40, dietKey: existingUser.activeDietKey.isEmpty ? "balanced" : existingUser.activeDietKey)
        } else {
            let newUser = User(
                name: "Champion",
                weight: Double(metrics.weight),
                height: Double(metrics.height),
                age: metrics.age,
                gender: "Male"
            )
            newUser.dailyCaloriesGoal = cals
            newUser.applyDietBreakdown(fatPercent: 30, proteinPercent: 30, carbsPercent: 40, dietKey: "balanced")
            context.insert(newUser)
        }
        try? context.save()
        
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
    // Without this the fancy onboarding re-appears on every cold launch.
    @AppStorage("hasCompletedInitialOnboarding_v2") private var hasCompletedInitialOnboarding = false

    @State private var currentStep: AppLaunchStep

    init() {
        // Initialize step from persisted flag so we don't force the account screen every launch
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedInitialOnboarding_v2")
        _currentStep = State(initialValue: completed ? .mainApp : .screen1)
    }

    var body: some View {
        ZStack {
            switch currentStep {
            case .screen1:
                
                OnboardingView(onSuccess: {
                    hasCompletedInitialOnboarding = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .mainApp
                    }
                })
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

            case .mainApp:
                
                ContentView() 
                    .transition(.opacity)
            }
        }
    }
}
