import json
import time
import re
from deep_translator import GoogleTranslator

file_path = 'Localizable.xcstrings'

langs = {
    'fr': 'fr',
    'de': 'de',
    'it': 'it',
    'pt-PT': 'pt',
    'ru': 'ru',
    'es': 'es'
}

def clean_placeholder(text):
    # Just standard translation, deep_translator handles %lld okay generally, 
    # but we can try to leave placeholders as is. 
    return text

print("Loading xcstrings...")
with open(file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

strings = data.get('strings', {})
total_keys = len(strings)
print(f"Found {total_keys} keys.")

# To track progress
for lang_code, dt_code in langs.items():
    print(f"--- Translating to {lang_code} ---")
    translator = GoogleTranslator(source='en', target=dt_code)
    
    # We will gather things to translate
    to_translate = []
    keys_to_translate = []
    
    for key, val in strings.items():
        if key.strip() == "":
            continue
            
        localizations = val.get('localizations', {})
        if lang_code not in localizations:
            to_translate.append(key)
            keys_to_translate.append(key)
        elif localizations[lang_code].get('stringUnit', {}).get('state') != 'translated':
            to_translate.append(key)
            keys_to_translate.append(key)
            
    if not to_translate:
        print(f"All strings already translated for {lang_code}.")
        continue
        
    print(f"Need to translate {len(to_translate)} items for {lang_code}.")
    
    # Translate one by one with a small sleep to show progress and avoid ban
    for i, (key, text) in enumerate(zip(keys_to_translate, to_translate)):
        if i % 20 == 0:
            print(f"Progress: [{i}/{len(to_translate)}] translated for {lang_code}...")
            time.sleep(1) # save rate limits
            
        try:
            translated_text = translator.translate(text)
            if not translated_text:
                translated_text = text
        except Exception as e:
            print(f"Error translating '{text}': {e}")
            translated_text = text
            time.sleep(2)
            
        if 'localizations' not in strings[key]:
            strings[key]['localizations'] = {}
            
        strings[key]['localizations'][lang_code] = {
            "stringUnit": {
                "state": "translated",
                "value": translated_text
            }
        }

print("Saving Localizable.xcstrings...")
with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print("Done with xcstrings!")
