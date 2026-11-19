import SwiftUI
import SwiftData

enum AIChatTitleHelper {
    static func deriveTitle(from raw: String) -> String {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else {
            return String(localized: "Diet Chat")
        }
        if collapsed.count <= 40 {
            return collapsed
        }
        return String(collapsed.prefix(37)) + "..."
    }

    static func buildUserContext(
        userGoal: Int,
        consumed: Int,
        consumedProtein: Double,
        targetProtein: Double,
        consumedFats: Double,
        targetFats: Double,
        consumedCarbs: Double,
        targetCarbs: Double,
        hydrationLiters: Double
    ) -> String {
        var parts = [
            "User's goal is \(userGoal) kcal. Today they have consumed \(consumed) kcal. Left: \(userGoal - consumed) kcal."
        ]
        if targetProtein > 0 || consumedProtein > 0 || targetFats > 0 || consumedFats > 0 || targetCarbs > 0 || consumedCarbs > 0 {
            parts.append(
                "Macros today: \(Int(consumedProtein.rounded()))/\(Int(targetProtein.rounded()))g protein, \(Int(consumedFats.rounded()))/\(Int(targetFats.rounded()))g fats, \(Int(consumedCarbs.rounded()))/\(Int(targetCarbs.rounded()))g carbs."
            )
        }
        if hydrationLiters > 0 {
            parts.append(String(format: "Hydration today: %.1f L water.", locale: Locale(identifier: "en_US_POSIX"), hydrationLiters))
        }
        return parts.joined(separator: " ")
    }
}

struct AICoachChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AIChatSession.date, order: .reverse) private var allSessions: [AIChatSession]

    let userGoal: Int
    let consumed: Int
    let activeDiet: String
    var initialContext: String? = nil
    var consumedProtein: Double = 0
    var targetProtein: Double = 0
    var consumedFats: Double = 0
    var targetFats: Double = 0
    var consumedCarbs: Double = 0
    var targetCarbs: Double = 0
    var hydrationLiters: Double = 0

    @State private var currentSession: AIChatSession?
    @State private var chatHistory: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var showHistorySheet = false
    @State private var showAIConsentSheet = false
    @State private var pendingMessageToSend = false
    @State private var activeTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            if chatHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                    Text("Ask your Coach")
                        .font(.title2).bold()
                    Text("Can I eat pizza tonight? How to get more protein? Ask anything.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(chatHistory) { message in
                                FoodChatMessageView(message: message)
                                    .id(message.id)
                            }
                            if isGenerating {
                                FoodAILoadingIndicator()
                                    .id("loading")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Color.clear.frame(height: 80).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: chatHistory) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: isGenerating) { _, _ in
                        withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                    }
                }
                .onTapGesture { isInputFocused = false }
            }

            VStack(spacing: 0) {
                // МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР (Guideline 1.4.1)
                Text("FoodTracker AI provides general nutritional information. Not medical advice.")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)

                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Type your question...", text: $inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .disabled(isGenerating)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor((inputText.isEmpty || isGenerating) ? .gray.opacity(0.5) : .themePink)
                    }
                    .disabled(inputText.isEmpty || isGenerating)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial)
        }
        .navigationTitle(currentSession?.title ?? "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHistorySheet = true } label: {
                    Image(systemName: "clock.arrow.circlepath").foregroundColor(.primary)
                }
                .disabled(isGenerating)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { clearChat() } label: {
                    Image(systemName: "square.and.pencil").foregroundColor(.primary)
                }
                .disabled(isGenerating)
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            FoodChatHistorySheet(
                sessions: allSessions,
                onSelect: { session in
                    loadSession(session)
                },
                onDeleteCurrent: { deletedSession in
                    if currentSession?.persistentModelID == deletedSession.persistentModelID {
                        clearChat()
                    }
                }
            )
        }
        .sheet(isPresented: $showAIConsentSheet) {
            AIPhotoConsentSheet(
                onAllow: {
                    if pendingMessageToSend {
                        pendingMessageToSend = false
                        sendMessage()
                    }
                },
                onDecline: {
                    pendingMessageToSend = false
                }
            )
        }
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
        }
        .onAppear {
            TrackingManager.shared.track(.featureDiscovered(feature: "AI Coach Chat"))
            if let contextMsg = initialContext, chatHistory.isEmpty {
                activeTask?.cancel()
                activeTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled, self.chatHistory.isEmpty else { return }
                    self.inputText = contextMsg
                    if AIPhotoConsentManager.shared.hasConsented {
                        self.sendMessage()
                    } else {
                        self.pendingMessageToSend = true
                        self.showAIConsentSheet = true
                    }
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard AIPhotoConsentManager.shared.hasConsented else {
            pendingMessageToSend = true
            showAIConsentSheet = true
            return
        }

        let userMsg = AIChatMessage(isUser: true, text: text)
        chatHistory.append(userMsg)
        inputText = ""
        isGenerating = true
        isInputFocused = false

        let isFirstMessage: Bool
        let targetSession: AIChatSession
        if let existing = currentSession {
            isFirstMessage = false
            targetSession = existing
        } else {
            isFirstMessage = true
            let newSession = AIChatSession()
            context.insert(newSession)
            currentSession = newSession
            targetSession = newSession
        }

        targetSession.messages.append(userMsg)
        try? context.save()

        // Use persisted session messages (excluding transient error bubbles and the just-sent prompt).
        let priorMessages = Array(targetSession.messages.dropLast().suffix(8))
        if isFirstMessage {
            targetSession.title = AIChatTitleHelper.deriveTitle(from: text)
            try? self.context.save()
        }

        activeTask = Task {
            let userContext = AIChatTitleHelper.buildUserContext(
                userGoal: userGoal,
                consumed: consumed,
                consumedProtein: consumedProtein,
                targetProtein: targetProtein,
                consumedFats: consumedFats,
                targetFats: targetFats,
                consumedCarbs: consumedCarbs,
                targetCarbs: targetCarbs,
                hydrationLiters: hydrationLiters
            )

            let aiResponseText = await AINutritionService.shared.sendChatMessage(
                prompt: text,
                userContext: userContext,
                activeDiet: activeDiet,
                history: priorMessages
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.isGenerating = false
                guard self.currentSession?.persistentModelID == targetSession.persistentModelID else { return }
                if let aiResponseText {
                    let aiMsg = AIChatMessage(isUser: false, text: aiResponseText, isAnimating: true)
                    self.chatHistory.append(aiMsg)
                    targetSession.messages.append(aiMsg)
                    try? self.context.save()
                } else {
                    // Show transient error message in UI without persisting fake AI text into SwiftData history.
                    let message = GeminiProxyClient.consumeRateLimitAlertMessage()
                        ?? String(localized: "I couldn't process that right now.")
                    let errorMsg = AIChatMessage(
                        isUser: false,
                        text: message,
                        isAnimating: false
                    )
                    self.chatHistory.append(errorMsg)
                }
            }
        }
    }

    private func loadSession(_ session: AIChatSession) {
        currentSession = session
        chatHistory = session.messages.map { var m = $0; m.isAnimating = false; return m }
    }

    private func clearChat() {
        currentSession = nil
        chatHistory = []
    }
}

struct FoodChatMessageView: View {
    let message: AIChatMessage
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 40) }
            else {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom)).frame(width: 32, height: 32)
                    Image(systemName: "sparkles").font(.caption.bold()).foregroundColor(.white)
                }
            }

            Group {
                if message.isUser {
                    Text(message.text)
                } else {
                    FoodTypewriterTextView(fullText: message.text, isAnimating: message.isAnimating)
                }
            }
            .font(.body)
            .foregroundColor(message.isUser ? .white : .primary)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(message.isUser ? Color.themePink : Color.white)
            .clipShape(FoodChatBubbleShape(isUser: message.isUser))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)

            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

struct FoodChatBubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight, isUser ? .bottomLeft : .bottomRight], cornerRadii: CGSize(width: 16, height: 16))
        return Path(path.cgPath)
    }
}

struct FoodTypewriterTextView: View {
    let fullText: String
    let isAnimating: Bool
    @State private var displayedText: String = ""
    @State private var timer: Timer?
    @State private var hasAnimated: Bool = false

    var body: some View {
        Text(displayedText)
            .onAppear {
                if isAnimating && !hasAnimated { startAnimating(); hasAnimated = true }
                else { displayedText = fullText }
            }
            .onDisappear { timer?.invalidate() }

            .onChange(of: fullText) { _, newValue in
                timer?.invalidate()
                displayedText = ""
                hasAnimated = false
                if isAnimating {
                    startAnimating()
                    hasAnimated = true
                } else {
                    displayedText = newValue
                }
            }
    }

    private func startAnimating() {
        displayedText = ""
        let chars = Array(fullText)
        var currentIndex = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { t in
            if currentIndex < chars.count {
                displayedText.append(chars[currentIndex])
                currentIndex += 1
            } else { t.invalidate() }
        }
    }
}

struct FoodAILoadingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom)).frame(width: 32, height: 32)
                Image(systemName: "sparkles").font(.caption.bold()).foregroundColor(.white)
            }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(Color.gray.opacity(0.6)).frame(width: 8, height: 8).offset(y: isAnimating ? -5 : 0)
                        .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.4).repeatForever().delay(0.15 * Double(i)), value: isAnimating)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.white).clipShape(FoodChatBubbleShape(isUser: false))
        }
        .onAppear { if !reduceMotion { isAnimating = true } }
    }
}

struct FoodChatHistorySheet: View {
    let sessions: [AIChatSession]
    var onSelect: (AIChatSession) -> Void
    var onDeleteCurrent: ((AIChatSession) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    Text("No chat history yet.").foregroundColor(.gray)
                } else {
                    ForEach(sessions) { session in
                        Button {
                            onSelect(session); dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(session.title).font(.headline).foregroundColor(.primary)
                                Text(session.date, style: .date).font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            let session = sessions[i]
                            onDeleteCurrent?(session)
                            context.delete(session)
                        }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
