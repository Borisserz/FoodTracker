import re
import os

files = [
    "FoodTracker/App/MonetkaOnboarding1.swift",
    "FoodTracker/App/MonetkaOnboarding2.swift",
    "FoodTracker/App/RemoteConfigManager.swift",
    "FoodTracker/App/ServerDataLoaders.swift",
    "FoodTracker/App/FoodTrackerApp.swift",
    "FoodTracker/AI/AICoachViewModel.swift",
    "FoodTracker/AI/AICoachChatView.swift",
    "FoodTracker/AI/AICoachDashboardView.swift",
    "FoodTracker/Views/Home/HomeDashboardView.swift",
    "FoodTracker/Views/AddMealView.swift",
    "FoodTracker/Views/Foods/SuperFoodsView.swift",
    "FoodTracker/Views/Chefs/ChefRecipesView.swift",
    "FoodTracker/Services/AcademyDataLoader.swift",
    "FoodTracker/Services/NetworkManager.swift",
    "FoodTracker/Services/RecipeDataLoader.swift",
    "FoodTracker/Services/BarcodeDatabaseService.swift"
]

translations = {
    # UI Text
    r'"ИИ-Ассистент"': r'"AI Assistant"',
    r'"Опробуй готовку с ИИ"': r'"Try AI Cooking"',
    r'"AI Шеф"': r'"AI Chef"',
    
    # AddMealView logic
    r' \|\| nameLower\.contains\("йогурт"\)': '',
    r' \|\| nameLower\.contains\("гранола"\) \|\| nameLower\.contains\("овсян"\)': '',
    r' \|\| nameLower\.contains\("кофе"\)': '',
    r' \|\| nameLower\.contains\("яблоко"\)': '',
    r' \|\| nameLower\.contains\("куриц"\)': '',
    r' \|\| nameLower\.contains\("авокадо"\)': '',
    r' \|\| nameLower\.contains\("яйцо"\) \|\| nameLower\.contains\("яиц"\)': '',
    r' \|\| nameLower\.contains\("салат"\)': '',
    r' \|\| nameLower\.contains\("мясо"\) \|\| nameLower\.contains\("стейк"\)': '',
    r' \|\| nameLower\.contains\("банан"\)': '',
    r' \|\| nameLower\.contains\("рыба"\) \|\| nameLower\.contains\("лосось"\)': '',
    r' \|\| nameLower\.contains\("вода"\)': '',
    
    # Print statements (Regex replacements)
    r'print\("❌ Ошибка загрузки Академии: \\\(error\.localizedDescription\)"\)': r'print("❌ Error loading Academy: \(error.localizedDescription)")',
    r'print\("✅ Академия загружена: \\\(self\.categories\.count\) категорий\."\)': r'print("✅ Academy loaded: \(self.categories.count) categories.")',
    r'print\("❌ Ошибка парсинга Академии: \\\(error\)"\)': r'print("❌ Error parsing Academy: \(error)")',
    r'print\("❌ Ошибка загрузки рецептов: \\\(error\.localizedDescription\)"\)': r'print("❌ Error loading recipes: \(error.localizedDescription)")',
    r'print\("✅ Все рецепты загружены! Всего: \\\(self\.recipes\.count\) шт\."\)': r'print("✅ All recipes loaded! Total: \(self.recipes.count)")',
    r'print\("❌ Ошибка парсинга рецептов: \\\(error\)"\)': r'print("❌ Error parsing recipes: \(error)")',
    
    # Comments (Strip anything starting with // and containing Cyrillic)
}

for filepath in files:
    if not os.path.exists(filepath): continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Strip Russian comments
    content = re.sub(r'//.*[А-Яа-яЁё].*', '', content)
    
    # Apply specific translations
    for k, v in translations.items():
        content = re.sub(k, v, content)
        
    # Generic Print translation for any remaining Cyrillic print
    content = re.sub(r'print\("[^"]*[А-Яа-яЁё][^"]*"\)', r'print("Log output removed for English localization")', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done translating files.")
