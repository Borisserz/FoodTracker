import json

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

update_ru("Synthesizing nutritional matrices...", "Синтезируем нутрициональные матрицы...")
update_ru("Aligning macros to your profile...", "Адаптируем макросы под ваш профиль...")
update_ru("Curating top-tier recipes...", "Подбираем лучшие рецепты...")
update_ru("Assembling the perfect week...", "Собираем идеальную неделю...")
update_ru("Finalizing your God-Tier Menu...", "Завершаем ваш идеальный план...")

update_ru("LOADING PHOTOS", "ЗАГРУЗКА ФОТО")
update_ru("AI CHEF AWAKENED", "ИИ-ПОВАР ПРОБУДИЛСЯ")
update_ru("Caching photo %lld of %lld", "Загрузка фото %lld из %lld")
update_ru("This may take 1–2 minutes.\nWe're building your entire week, including meal photos.", "Это может занять 1–2 минуты.\nМы собираем всю вашу неделю, включая фотографии блюд.")

with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
    json.dump(strings_data, f, indent=2, ensure_ascii=False)

print("Added more SmartPlan translations!")
