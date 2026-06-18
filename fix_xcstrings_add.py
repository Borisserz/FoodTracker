import json

path = './Localizable.xcstrings'
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

def add_translation(key, ru_val, en_val=None):
    if key not in data['strings']:
        data['strings'][key] = {
            "extractionState": "manual",
            "localizations": {}
        }
    if 'localizations' not in data['strings'][key]:
        data['strings'][key]['localizations'] = {}
        
    data['strings'][key]['localizations']['ru'] = {
        "stringUnit": {
            "state": "translated",
            "value": ru_val
        }
    }
    
    if en_val:
        data['strings'][key]['localizations']['en'] = {
            "stringUnit": {
                "state": "translated",
                "value": en_val
            }
        }

add_translation("Add to", "Добавить к", "Add to")
add_translation("Added to", "Добавлено к", "Added to")
add_translation("Learn more", "Узнать больше", "Learn more")

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

