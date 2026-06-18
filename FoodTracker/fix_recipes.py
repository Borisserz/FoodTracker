import json

with open('recipes.json', 'r', encoding='utf-8') as f:
    en_recipes = json.load(f)

with open('recipes_ru.json', 'r', encoding='utf-8') as f:
    ru_recipes = json.load(f)

with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
    strings_data = json.load(f)

def update_ru(key, new_value):
    if key not in strings_data.get("strings", {}):
        strings_data["strings"][key] = {"extractionState": "manual", "localizations": {}}
        
    if "localizations" not in strings_data["strings"][key]:
        strings_data["strings"][key]["localizations"] = {}
    
    if "ru" not in strings_data["strings"][key]["localizations"]:
        strings_data["strings"][key]["localizations"]["ru"] = {"stringUnit": {"state": "translated", "value": ""}}
        
    strings_data["strings"][key]["localizations"]["ru"]["stringUnit"]["value"] = new_value
    strings_data["strings"][key]["localizations"]["ru"]["stringUnit"]["state"] = "translated"

for i in range(len(en_recipes)):
    en_title = en_recipes[i].get("title", "")
    ru_title = ru_recipes[i].get("title", "")
    if en_title and ru_title:
        update_ru(en_title, ru_title)
        
    en_desc = en_recipes[i].get("description", "")
    ru_desc = ru_recipes[i].get("description", "")
    if en_desc and ru_desc:
        update_ru(en_desc, ru_desc)
        
    # Also localize tags!
    for j in range(len(en_recipes[i].get("tags", []))):
        en_tag = en_recipes[i]["tags"][j]
        ru_tag = ru_recipes[i]["tags"][j] if j < len(ru_recipes[i].get("tags", [])) else en_tag
        if en_tag and ru_tag:
            update_ru(en_tag, ru_tag)
            
    # Also localize ingredients!
    for j in range(len(en_recipes[i].get("ingredients", []))):
        en_ing = en_recipes[i]["ingredients"][j].get("name", "")
        ru_ing = ru_recipes[i]["ingredients"][j].get("name", "") if j < len(ru_recipes[i].get("ingredients", [])) else en_ing
        if en_ing and ru_ing:
            update_ru(en_ing, ru_ing)
            
# Don't forget DietCard titles and subtitles!
update_ru("Any", "Любая")
update_ru("No restrictions", "Без ограничений")
update_ru("Keto", "Кето")
update_ru("High fat, low carb", "Много жиров, мало углеводов")
update_ru("Vegan", "Веган")
update_ru("100% plant-based", "Только растительная пища")
update_ru("Vegetarian", "Вегетарианская")
update_ru("Plant-based, no meat", "Без мяса")
update_ru("Paleo", "Палео")
update_ru("Natural whole foods", "Натуральные цельные продукты")
update_ru("Pescatarian", "Пескетарианская")
update_ru("Fish and seafood", "Рыба и морепродукты")
update_ru("Mediterranean", "Средиземноморская")
update_ru("Olive oil and veggies", "Оливковое масло и овощи")
update_ru("High Protein", "Высокий белок")
update_ru("High protein for muscles", "Много белка для мышц")
update_ru("Low Carb", "Мало углеводов")
update_ru("Minimum carbs", "Минимум углеводов")

update_ru("Fast (15m)", "Быстро (15м)")
update_ru("Medium (30m)", "Средне (30м)")
update_ru("Chef (60m)", "Шеф (60м)")

update_ru("7-Day Protocol", "7-дневный план")
update_ru("AI Menu Builder", "Конструктор ИИ")
update_ru("Build a 7-Day Plan", "Создать план на 7 дней")

with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
    json.dump(strings_data, f, indent=2, ensure_ascii=False)

print("Added recipe translations!")
