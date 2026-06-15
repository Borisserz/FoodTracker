import json
import time
import os
from deep_translator import GoogleTranslator

langs = {
    'en': 'en',
    'fr': 'fr',
    'de': 'de',
    'it': 'it',
    'pt-PT': 'pt',
    'ru': 'ru',
    'es': 'es'
}

def trans(text, translator):
    if not text or not isinstance(text, str): return text
    try:
        time.sleep(0.1)
        res = translator.translate(text)
        return res if res else text
    except Exception as e:
        print(f"Error translating: {e}")
        time.sleep(2)
        return text

with open('FoodTracker/new_recipes.json', 'r', encoding='utf-8') as f:
    new_recipes = json.load(f)

for lang_code, dt_code in langs.items():
    print(f"--- Translating and appending new recipes to {lang_code} ---")
    
    if lang_code == 'en':
        translated_recipes = new_recipes
        target_file = 'FoodTracker/recipes.json'
    else:
        translator = GoogleTranslator(source='en', target=dt_code)
        translated_recipes = []
        for i, r in enumerate(new_recipes):
            print(f"Recipe {i+1}/{len(new_recipes)} for {lang_code}...")
            r_copy = json.loads(json.dumps(r)) # deep copy
            r_copy['title'] = trans(r.get('title'), translator)
            r_copy['description'] = trans(r.get('description'), translator)
            
            tags = r.get('tags', [])
            r_copy['tags'] = [trans(t, translator) for t in tags]
            
            for ing in r_copy.get('ingredients', []):
                ing['name'] = trans(ing.get('name'), translator)
                
            dirs = r_copy.get('directions', [])
            r_copy['directions'] = [trans(d, translator) for d in dirs]
            translated_recipes.append(r_copy)
            
        target_file = f'FoodTracker/recipes_{lang_code}.json'
        
    # Append to target file
    if os.path.exists(target_file):
        with open(target_file, 'r', encoding='utf-8') as f:
            existing = json.load(f)
    else:
        existing = []
        
    existing.extend(translated_recipes)
    
    with open(target_file, 'w', encoding='utf-8') as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)

print("All translations and appending complete!")
