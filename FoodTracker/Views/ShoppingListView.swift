import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var showsDismissButton: Bool = false

    @Query(sort: \ShoppingItem.dateAdded, order: .reverse) private var allItems: [ShoppingItem]

    @State private var newItemName: String = ""
    @State private var newItemAmount: String = ""

    var activeItems: [ShoppingItem] { allItems.filter { !$0.isChecked } }
    var completedItems: [ShoppingItem] { allItems.filter { $0.isChecked } }

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 0) {

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.gray)
                        TextField("Add an item (e.g. Milk)...", text: $newItemName)
                            .onSubmit { addManualItem() }
                        Divider().frame(height: 20)
                        TextField("Qty", text: $newItemAmount)
                            .frame(width: 68)
                            .multilineTextAlignment(.trailing)
                            .onSubmit { addManualItem() }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)

                    Button(action: addManualItem) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.themePink)
                            .cornerRadius(14)
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add Item")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        if allItems.isEmpty {
                            EmptyStateView(
                                imageName: "cart",
                                title: "Your cart is empty",
                                description: "Add items manually or export ingredients directly from recipes."
                            )
                            .padding(.top, 60)
                        } else {

                            if !activeItems.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("To Buy (\(activeItems.count))")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 24)

                                    VStack(spacing: 0) {
                                        ForEach(activeItems) { item in
                                            ShoppingRowView(item: item, onToggle: { toggleCheck(for: item) }, onDelete: { deleteItem(item) })
                                            if item.id != activeItems.last?.id {
                                                Divider().padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .padding(.horizontal, 20)
                                    .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
                                }
                            }

                            if !completedItems.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Completed")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Button("Clear All") { clearCompleted() }
                                            .font(.caption.bold())
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 24)

                                    VStack(spacing: 0) {
                                        ForEach(completedItems) { item in
                                            ShoppingRowView(item: item, onToggle: { toggleCheck(for: item) }, onDelete: { deleteItem(item) })
                                            if item.id != completedItems.last?.id {
                                                Divider().padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .padding(.horizontal, 20)
                                    .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
                                    .opacity(0.7)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .navigationTitle("Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveAndReloadWidgets() {
        try? context.save()
        WidgetReloader.reloadAll()
    }

    private func addManualItem() {
        let text = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = newItemAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        HapticManager.shared.impact(style: .light)
        ShoppingItem.insertDeduplicated(
            items: [(name: text, amount: amount)],
            in: context
        )
        saveAndReloadWidgets()
        newItemName = ""
        newItemAmount = ""
    }

    private func toggleCheck(for item: ShoppingItem) {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            item.isChecked.toggle()
        }
        saveAndReloadWidgets()
    }

    private func deleteItem(_ item: ShoppingItem) {
        withAnimation {
            context.delete(item)
            saveAndReloadWidgets()
        }
    }

    private func clearCompleted() {
        HapticManager.shared.impact(style: .medium)
        withAnimation {
            for item in completedItems {
                context.delete(item)
            }
            saveAndReloadWidgets()
        }
    }
}

struct ShoppingRowView: View {
    @Bindable var item: ShoppingItem
    var onToggle: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggle) {
                HStack(spacing: 16) {

                    ZStack {
                        Circle()
                            .stroke(item.isChecked ? Color.themePink : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if item.isChecked {
                            Circle()
                                .fill(Color.themePink)
                                .frame(width: 24, height: 24)
                                .transition(.scale)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(item.isChecked ? .gray : .primary)
                            .strikethrough(item.isChecked, color: .gray)

                        HStack {
                            if !item.amount.isEmpty {
                                Text(item.amount)
                                    .font(.caption.bold())
                                    .foregroundColor(.themeOrange)
                            }

                            if let recipeName = item.addedFromRecipe {
                                Text("from \(recipeName)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            if let onDelete = onDelete {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                        .padding(8)
                }
                .accessibilityLabel("Delete")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .contextMenu {
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
