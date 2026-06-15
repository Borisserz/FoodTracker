import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @Query(sort: \ShoppingItem.dateAdded, order: .reverse) private var allItems: [ShoppingItem]

    @State private var newItemName: String = ""
    @State private var bgRotation: Double = 0
    @FocusState private var isInputFocused: Bool

    var activeItems: [ShoppingItem] { allItems.filter { !$0.isChecked } }
    var completedItems: [ShoppingItem] { allItems.filter { $0.isChecked } }
    
    var progress: Double {
        if allItems.isEmpty { return 0 }
        return Double(completedItems.count) / Double(allItems.count)
    }

    var suggestedItems: [String] {
        // Find most frequent completed items that are NOT currently active
        let activeNames = Set(activeItems.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        var frequency: [String: Int] = [:]
        
        for item in completedItems {
            let name = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !activeNames.contains(name) && !name.isEmpty {
                // Store original case but use lowercase for uniqueness check
                frequency[item.name, default: 0] += 1
            }
        }
        
        // Return top 8 most frequent
        return frequency.sorted { $0.value > $1.value }.prefix(8).map { $0.key }
    }
    
    var shareText: String {
        guard !activeItems.isEmpty else {
            return "My Smart Cart is empty!"
        }
        var text = "🛒 Smart Cart:\n\n"
        for item in activeItems {
            let amountStr = item.amount.isEmpty ? "" : " (\(item.amount))"
            text += "• \(item.name)\(amountStr)\n"
        }
        return text
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ethereal Animated Background
            Color.themeBg.ignoresSafeArea()
            
            GeometryReader { proxy in
                ZStack {
                    AngularGradient(
                        gradient: Gradient(colors: [
                            themeManager.current.primaryAccent.opacity(0.15),
                            Color.themePink.opacity(0.1),
                            Color.themeOrange.opacity(0.15),
                            Color.themeYellow.opacity(0.1),
                            themeManager.current.primaryAccent.opacity(0.15)
                        ]),
                        center: .center,
                        angle: .degrees(bgRotation)
                    )
                    .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 1.5)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .blur(radius: 60)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    bgRotation = 360
                }
            }

            VStack(spacing: 0) {
                // Custom Hero Header
                HStack(spacing: 20) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Cart")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(allItems.isEmpty ? "Ready for ingredients" : "\(activeItems.count) remaining")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if !activeItems.isEmpty {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3.bold())
                                .foregroundColor(themeManager.current.primaryAccent)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                        }
                    }
                    
                    // Circular Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(themeManager.current.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if allItems.isEmpty {
                            EmptyStateView(
                                imageName: "cart",
                                title: "Your cart is empty",
                                description: "Add items manually or export ingredients directly from recipes."
                            )
                            .padding(.top, 80)
                        } else {
                            if !activeItems.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(activeItems) { item in
                                        GodTierShoppingRow(item: item, onToggle: { toggleCheck(for: item) }, onDelete: { deleteItem(item) })
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            if !completedItems.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Completed")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Button(action: clearCompleted) {
                                            Text("Clear All")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.top, 16)

                                    VStack(spacing: 12) {
                                        ForEach(completedItems) { item in
                                            GodTierShoppingRow(item: item, onToggle: { toggleCheck(for: item) }, onDelete: { deleteItem(item) })
                                        }
                                    }
                                }
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .cornerRadius(32)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 160) // Space for bottom dock and suggestions
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // Bottom Floating Input Dock
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, Color.themeBg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
                
                ZStack(alignment: .bottom) {
                    Color.themeBg.ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        // Smart Suggestions Row
                        if isInputFocused && !suggestedItems.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(suggestedItems, id: \.self) { suggestion in
                                        Button(action: {
                                            addQuickItem(name: suggestion)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 10, weight: .bold))
                                                Text(suggestion)
                                                    .font(.subheadline.bold())
                                            }
                                            .foregroundColor(themeManager.current.primaryAccent)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(20)
                                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(themeManager.current.primaryAccent.opacity(0.3), lineWidth: 1))
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Input Field
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(themeManager.current.primaryAccent)
                                
                                TextField("Add an item...", text: $newItemName)
                                    .focused($isInputFocused)
                                    .submitLabel(.done)
                                    .onSubmit { addManualItem() }
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.5), lineWidth: 1))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                            if !newItemName.isEmpty {
                                Button(action: addManualItem) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(themeManager.current.primaryGradient)
                                        .clipShape(Circle())
                                        .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, y: 5)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationBarHidden(true)
    }

    private func addManualItem() {
        let text = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        HapticManager.shared.impact(style: .medium)
        let item = ShoppingItem(name: text)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            context.insert(item)
            try? context.save()
            newItemName = ""
        }
        // Keep focus so user can type multiple items fast
        isInputFocused = true
    }
    
    private func addQuickItem(name: String) {
        HapticManager.shared.impact(style: .medium)
        let item = ShoppingItem(name: name)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            context.insert(item)
            try? context.save()
        }
    }

    private func toggleCheck(for item: ShoppingItem) {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            item.isChecked.toggle()
        }
        try? context.save()
    }

    private func deleteItem(_ item: ShoppingItem) {
        HapticManager.shared.impact(style: .medium)
        withAnimation {
            context.delete(item)
            try? context.save()
        }
    }

    private func clearCompleted() {
        HapticManager.shared.impact(style: .heavy)
        withAnimation {
            for item in completedItems {
                context.delete(item)
            }
            try? context.save()
        }
    }
}

struct GodTierShoppingRow: View {
    @Bindable var item: ShoppingItem
    var onToggle: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(item.isChecked ? themeManager.current.primaryAccent : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if item.isChecked {
                        Circle()
                            .fill(themeManager.current.primaryGradient)
                            .frame(width: 28, height: 28)
                            .transition(.scale.combined(with: .opacity))

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(item.isChecked ? .gray : .primary)
                    .strikethrough(item.isChecked, color: .gray)
                    .animation(.easeInOut, value: item.isChecked)

                HStack {
                    if !item.amount.isEmpty {
                        Text(item.amount)
                            .font(.caption.bold())
                            .foregroundColor(themeManager.current.primaryAccent)
                    }

                    if let recipeName = item.addedFromRecipe {
                        Text("from \(recipeName)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ZStack {
                if item.isChecked {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    Rectangle().fill(Color.white)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(item.isChecked ? Color.clear : Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
