//
//  AICoachChatView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 15.04.26.
//

// FILE: FoodTracker/Views/AICoach/AICoachChatView.swift

import SwiftUI
import SwiftData

struct AICoachChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AIChatSession.date, order: .reverse) private var allSessions: [AIChatSession]
    
    let userGoal: Int
    let consumed: Int
    
    @State private var currentSession: AIChatSession?
    @State private var chatHistory: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false
    @FocusState private var isInputFocused: Bool
    
    @State private var showHistorySheet = false
    
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
            
            // Input Area
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
            .background(.ultraThinMaterial)
        }
        .navigationTitle(currentSession?.title ?? "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHistorySheet = true } label: {
                    Image(systemName: "clock.arrow.circlepath").foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { clearChat() } label: {
                    Image(systemName: "square.and.pencil").foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            FoodChatHistorySheet(sessions: allSessions) { session in
                loadSession(session)
            }
        }
    }
    
    // MARK: - Logic
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMsg = AIChatMessage(isUser: true, text: text)
        chatHistory.append(userMsg)
        inputText = ""
        isGenerating = true
        isInputFocused = false
        
        var isFirstMessage = false
        if currentSession == nil {
            isFirstMessage = true
            let newSession = AIChatSession()
            context.insert(newSession)
            currentSession = newSession
        }
        
        currentSession?.messages.append(userMsg)
        try? context.save()
        
        Task {
            if isFirstMessage {
                let title = await AINutritionService.shared.generateChatTitle(for: text)
                await MainActor.run { self.currentSession?.title = title; try? context.save() }
            }
            
            let userContext = "User's goal is \(userGoal) kcal. Today they have consumed \(consumed) kcal. Left: \(userGoal - consumed) kcal."
            
            let aiResponseText = await AINutritionService.shared.sendChatMessage(prompt: text, userContext: userContext) ?? "I couldn't process that right now."
            
            await MainActor.run {
                let aiMsg = AIChatMessage(isUser: false, text: aiResponseText, isAnimating: true)
                self.chatHistory.append(aiMsg)
                self.currentSession?.messages.append(aiMsg)
                try? self.context.save()
                self.isGenerating = false
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

// MARK: - Chat UI Components
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
                        .animation(Animation.easeInOut(duration: 0.4).repeatForever().delay(0.15 * Double(i)), value: isAnimating)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.white).clipShape(FoodChatBubbleShape(isUser: false))
        }
        .onAppear { isAnimating = true }
    }
}

struct FoodChatHistorySheet: View {
    let sessions: [AIChatSession]
    var onSelect: (AIChatSession) -> Void
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
                        for i in indexSet { context.delete(sessions[i]) }
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
