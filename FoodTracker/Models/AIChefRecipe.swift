//
//  AIChefRecipe.swift
//  FoodTracker
//

import Foundation

// MARK: - 📦 Модели Данных AI Chef
public struct RecipeStep: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var instruction: String
    public var imageName: String
    public var aiTip: String?
    
    public init(id: String = UUID().uuidString, instruction: String, imageName: String, aiTip: String? = nil) {
        self.id = id
        self.instruction = instruction
        self.imageName = imageName
        self.aiTip = aiTip
    }
}

public struct AIChefRecipe: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var calories: Int
    public var protein: Int
    public var fat: Int
    public var carbs: Int
    public var heroImage: String
    public var cookTime: Int
    public var difficulty: Int // 1-5
    public var history: String
    public var ingredients: [String]
    public var steps: [RecipeStep]
    public var platingTip: String
    public var tags: [String]
    
    public init(id: String = UUID().uuidString, title: String, calories: Int, protein: Int, fat: Int = 0, carbs: Int = 0, heroImage: String, cookTime: Int, difficulty: Int, history: String, ingredients: [String], steps: [RecipeStep], platingTip: String, tags: [String] = []) {
        self.id = id
        self.title = title
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.heroImage = heroImage
        self.cookTime = cookTime
        self.difficulty = difficulty
        self.history = history
        self.ingredients = ingredients
        self.steps = steps
        self.platingTip = platingTip
        self.tags = tags
    }
}
