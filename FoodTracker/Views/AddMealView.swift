import SwiftUI
import SwiftData

// MARK: - ADD MEAL VIEW (Updated to use SmartAddFoodView)
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
            // ИСПРАВЛЕНИЕ: Используем новое имя SmartAddFoodView и передаем тип приема пищи
            .sheet(isPresented: $showingAddFood) {
                SmartAddFoodView(mealTitle: selectedMealType) { newItems in
                    self.selectedFoods.append(contentsOf: newItems)
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
            }
        }
    }
    
    private func deleteFood(at offsets: IndexSet) {
        selectedFoods.remove(atOffsets: offsets)
    }
    
    private func saveMealAndDismiss() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        
        let summaryToUse: DailySummary
        if let existingSummary = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            summaryToUse = existingSummary
        } else {
            summaryToUse = DailySummary(date: startOfDay)
            modelContext.insert(summaryToUse)
        }
        
        if let existingMeal = summaryToUse.meals.first(where: { $0.title == selectedMealType }) {
            existingMeal.foodItems.append(contentsOf: selectedFoods)
        } else {
            let newMeal = Meal(title: selectedMealType, date: selectedDate, foodItems: selectedFoods)
            summaryToUse.meals.append(newMeal)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save meal: \(error.localizedDescription)")
        }
    }
}
