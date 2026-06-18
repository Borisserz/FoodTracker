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

update_ru("Under 300", "До 300")
update_ru("300 - 450", "300 - 450")
update_ru("450 - 600", "450 - 600")
update_ru("Over 600", "Более 600")

with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
    json.dump(strings_data, f, indent=2, ensure_ascii=False)

print("Added calorie range translations!")
