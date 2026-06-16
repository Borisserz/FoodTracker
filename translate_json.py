import json
import time
import os
from deep_translator import GoogleTranslator

langs = {
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
        # Avoid overwhelming the API
        time.sleep(0.1)
        res = translator.translate(text)
        return res if res else text
    except Exception as e:
        print(f"Error translating: {e}")
        time.sleep(2)
        return text

def translate_recipes(lang_code, dt_code):
    print(f"--- Translating recipes to {lang_code} ---")
    translator = GoogleTranslator(source='en', target=dt_code)
    
    with open('FoodTracker/recipes.json', 'r', encoding='utf-8') as f:
        recipes = json.load(f)
        
    for i, r in enumerate(recipes):
        print(f"Recipe {i+1}/{len(recipes)}...")
        r['title'] = trans(r.get('title'), translator)
        r['description'] = trans(r.get('description'), translator)
        
        tags = r.get('tags', [])
        r['tags'] = [trans(t, translator) for t in tags]
        
        for ing in r.get('ingredients', []):
            ing['name'] = trans(ing.get('name'), translator)
            
        dirs = r.get('directions', [])
        r['directions'] = [trans(d, translator) for d in dirs]
        
    out_file = f'FoodTracker/recipes_{lang_code}.json'
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(recipes, f, indent=2, ensure_ascii=False)
        
def translate_academy(lang_code, dt_code):
    print(f"--- Translating academy to {lang_code} ---")
    translator = GoogleTranslator(source='en', target=dt_code)
    
    with open('FoodTracker/academy.json', 'r', encoding='utf-8') as f:
        academy = json.load(f)
        
    for i, course in enumerate(academy):
        print(f"Course {i+1}/{len(academy)}...")
        course['title'] = trans(course.get('title'), translator)
        
        for art in course.get('articles', []):
            art['title'] = trans(art.get('title'), translator)
            art['subtitle'] = trans(art.get('subtitle'), translator)
            art['content'] = trans(art.get('content'), translator)
            
    out_file = f'FoodTracker/academy_{lang_code}.json'
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(academy, f, indent=2, ensure_ascii=False)

def translate_new_recipes(lang_code, dt_code):
    print(f"--- Translating new_recipes to {lang_code} ---")
    translator = GoogleTranslator(source='en', target=dt_code)
    
    if not os.path.exists('FoodTracker/new_recipes.json'): return
    with open('FoodTracker/new_recipes.json', 'r', encoding='utf-8') as f:
        recipes = json.load(f)
        
    for i, r in enumerate(recipes):
        print(f"New Recipe {i+1}/{len(recipes)}...")
        r['title'] = trans(r.get('title'), translator)
        r['description'] = trans(r.get('description'), translator)
        
        tags = r.get('tags', [])
        r['tags'] = [trans(t, translator) for t in tags]
        
        for ing in r.get('ingredients', []):
            ing['name'] = trans(ing.get('name'), translator)
            
        dirs = r.get('directions', [])
        r['directions'] = [trans(d, translator) for d in dirs]
        
    out_file = f'FoodTracker/new_recipes_{lang_code}.json'
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(recipes, f, indent=2, ensure_ascii=False)

for lang_code, dt_code in langs.items():
    # translate_recipes(lang_code, dt_code)
    translate_new_recipes(lang_code, dt_code)
    # translate_academy(lang_code, dt_code)
    
print("All JSON translations complete!")
