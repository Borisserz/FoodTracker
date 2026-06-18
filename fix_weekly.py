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

update_ru("AI Weekly Protocol", "Еженедельный протокол AI")
update_ru("Optimal Synergy Reached", "Оптимальная синергия достигнута")
update_ru("A perfect 7-day alignment tailored to your metabolic goals.", "Идеальный план на 7 дней, созданный для ваших целей.")
update_ru("Mon", "Пн")
update_ru("Tue", "Вт")
update_ru("Wed", "Ср")
update_ru("Thu", "Чт")
update_ru("Fri", "Пт")
update_ru("Sat", "Сб")
update_ru("Sun", "Вс")

for i in range(1, 8):
    update_ru(f"D{i}", f"Д{i}")

with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
    json.dump(strings_data, f, indent=2, ensure_ascii=False)

print("Added weekly strings!")
