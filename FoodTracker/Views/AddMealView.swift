import SwiftUI
import SwiftData

// MARK: - ADD MEAL VIEW (Refactored for new AddFoodSelectionView)
struct AddMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var summaries: [DailySummary]
    
    @State private var selectedMealType = "Breakfast"
    @State private var selectedFoods: [FoodItem] = []
    @State private var showingAddFood = false
    
    let mealTypes = ["Breakfast", "Lunch", "Snack", "Dinner"]
    let selectedDate: Date
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Details") {
                    Picker("Meal Type", selection: $selectedMealType) {
                        ForEach(mealTypes, id: \.self) { Text($0) }
                    }
                }
                
                Section("Foods") {
                    if selectedFoods.isEmpty {
                        Text("No food items added yet.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(selectedFoods, id: \.name) { food in
                            HStack {
                                Text(food.name)
                                Spacer()
                                Text("\(food.calories) kcal").foregroundColor(.themePink)
                            }
                        }
                        .onDelete(perform: deleteFood)
                    }
                    
                    Button(action: { showingAddFood = true }) {
                        Label("Add Food Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Log Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMealAndDismiss() }
                        .disabled(selectedFoods.isEmpty)
                }
            }
            .tint(.themePink)
            // --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
            // Теперь мы передаем замыкание `onSave`, а не `Binding`.
            .sheet(isPresented: $showingAddFood) {
                AddFoodSelectionView { newItems in
                    // Этот код выполнится, когда пользователь нажмет "Add" в модальном окне.
                    self.selectedFoods.append(contentsOf: newItems)
                }
            }
        }
    }
    
    private func deleteFood(at offsets: IndexSet) {
        selectedFoods.remove(atOffsets: offsets)
    }
    
    private func saveMealAndDismiss() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        
        // 1. Найти или создать DailySummary для выбранной даты
        let summaryToUse: DailySummary
        if let existingSummary = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            summaryToUse = existingSummary
        } else {
            summaryToUse = DailySummary(date: startOfDay)
            modelContext.insert(summaryToUse)
        }
        
        // 2. Создать Meal и добавить в него FoodItems
        // Важно: если такой прием пищи уже есть, добавляем еду к нему, а не создаем дубликат
        if let existingMeal = summaryToUse.meals.first(where: { $0.title == selectedMealType }) {
            existingMeal.foodItems.append(contentsOf: selectedFoods)
        } else {
            let newMeal = Meal(title: selectedMealType, date: selectedDate, foodItems: selectedFoods)
            summaryToUse.meals.append(newMeal)
        }
        
        // 3. Сохранить изменения
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save meal: \(error.localizedDescription)")
        }
    }
}
