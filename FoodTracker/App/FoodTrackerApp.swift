import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static weak var activeAppState: AppStateManager?
    @MainActor static var pendingNotificationRoute: String?

    nonisolated static func notificationDeepLinkRoute(
        identifier: String,
        categoryIdentifier: String
    ) -> String? {
        let upperID = identifier.uppercased()
        let upperCategory = categoryIdentifier.uppercased()
        if upperID.hasPrefix("FASTING_") || upperID.hasPrefix("PHASE_") || upperCategory.hasPrefix("FASTING_") {
            return "fasting"
        }
        return nil
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppCheck.setAppCheckProviderFactory(AppCheckFactory())
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTestingResetOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedInitialOnboarding_v2")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding_v2")
        }
        if args.contains("-uiTestingSkipOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedInitialOnboarding_v2")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_v2")
        }
        if args.contains("-uiTestingDisableSpotlight") {
            UserDefaults.standard.set(true, forKey: "hasCompletedSpotlightTour_v5")
        }
        #endif
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        if let route = Self.notificationDeepLinkRoute(
            identifier: request.identifier,
            categoryIdentifier: request.content.categoryIdentifier
        ) {
            Task { @MainActor in
                if let appState = Self.activeAppState {
                    appState.requestedWidgetAction = route
                } else {
                    Self.pendingNotificationRoute = route
                }
            }
        }
        completionHandler()
    }
}

@main
struct FoodTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Migrated from @StateObject/ObservableObject to @Observable per system-rules and swiftui-pro
    @Environment(\.scenePhase) private var scenePhase
    @State private var versionManager = VersionManager.shared
    @State private var geminiClient = GeminiProxyClient.shared

    @State private var diContainer: DIContainer?
    @State private var showInMemoryStorageWarning = false

    var body: some Scene {
        WindowGroup {
            Group {
                if versionManager.updateRequirement == .hardUpdate {
                    VStack {
                        Text("Update Required")
                            .font(.title).bold()
                        Text("Please update to the latest version to continue.")
                            .multilineTextAlignment(.center).padding()
                        Button("Update Now") { AppReviewManager.openAppStoreProductPage() }
                            .buttonStyle(.borderedProminent)
                    }
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
                Button("Update Now") { AppReviewManager.openAppStoreProductPage() }
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
            .alert("Temporary Storage Mode", isPresented: $showInMemoryStorageWarning) {
                Button("OK", role: .cancel) { showInMemoryStorageWarning = false }
            } message: {
                Text("Your device storage database could not be opened, so changes may not persist after closing the app. Free up storage space and restart.")
            }
            .onAppear {
                TrackingManager.shared.track(.appOpened(source: "launch"))
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    FastingManager.shared.refreshOnForeground()
                    if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding_v2"),
                       !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiTesting") }) {
                        Task { await ReminderNotificationScheduler.syncOnAppActive() }
                    }
                    if !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiTesting") }) {
                        Task {
                            await RemoteConfigManager.shared.fetchCloudValues()
                            await VersionManager.shared.checkVersion()
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func setupDependencies() async {
        print("🚀 [setupDependencies] Starting initialization...")
        let useMetric = UserDefaults.standard.object(forKey: "useMetricSystem") as? Bool ?? true
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)?.set(useMetric, forKey: "useMetricSystem")

        let (container, inMemoryFallback) = await Task.detached(priority: .userInitiated) {
            (SharedModelContainer.shared.container, SharedModelContainer.shared.didFallBackToInMemory)
        }.value

        let di = DIContainer(modelContainer: container)
        AppDelegate.activeAppState = di.appState
        if let pendingRoute = AppDelegate.pendingNotificationRoute {
            di.appState.requestedWidgetAction = pendingRoute
            AppDelegate.pendingNotificationRoute = nil
        }
        self.diContainer = di
        if inMemoryFallback {
            self.showInMemoryStorageWarning = true
        }
        print("🚀 [setupDependencies] diContainer assigned to state using SharedModelContainer. Re-rendering UI...")

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
            
            // Invisible anchor aligned over Tab 2 ("AI Chef") for SpotlightTour
            VStack {
                Spacer()
                Color.clear
                    .frame(width: 64, height: 48)
                    .spotlightTarget(step: .aiChef)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(.keyboard)

            // In-App Interactive Spotlight Tutorial
            SpotlightOverlayView()
        }
        .coordinateSpace(name: "SpotlightCoordinateSpace")
        .onPreferenceChange(SpotlightFramePreferenceKey.self) { frames in
            SpotlightTourManager.shared.targetFrames = frames
        }
        .onOpenURL { url in
            if !appState.handleWidgetURL(url) {
                _ = GIDSignIn.sharedInstance.handle(url)
            }
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
        .sheet(isPresented: Binding(
            get: { appState.requestedWidgetAction == "fasting" },
            set: { if !$0 { appState.requestedWidgetAction = nil } }
        )) {
            NavigationStack {
                FastingDashboardView(showsDismissButton: true)
            }
        }
        .onAppear {
            initializeUserIfNeeded()
            SpotlightTourManager.shared.startTourIfNeeded()
            if !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiTesting") }) {
                Task { await ReminderNotificationScheduler.syncOnAppActive() }
            }

            if let user = users.first, user.isHealthKitEnabled {
                Task {
                    try? await HealthKitManager.shared.requestAuthorization()
                }
            }
        }
    }

    private func initializeUserIfNeeded() {
        if users.count > 1 {
            _ = User.deduplicatedPrimary(in: context)
            try? context.save()
            return
        }
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
        if !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiTesting") }) {
            Task { await ReminderNotificationScheduler.syncOnAppActive(forcePrompt: true) }
        }
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
