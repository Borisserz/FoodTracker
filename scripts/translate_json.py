import json
import os
import time
from deep_translator import GoogleTranslator

TARGET_LANGS = {
    "ru": "ru",
    "es": "es",
    "fr": "fr",
    "de": "de",
    "it": "it",
    "pt-PT": "pt"
}

def translate_text(text, target_lang_code):
    if not text or not text.strip():
        return text
    try:
        translator = GoogleTranslator(source='auto', target=target_lang_code)
        # Deep translator handles chunks under 5k chars natively
        translated = translator.translate(text)
        return translated
    except Exception as e:
        print(f"❌ Translation error: {e}")
        time.sleep(2)
        return text

def translate_recipes(lang_code, lang_target):
    print(f"\n🌍 Translating recipes.json to {lang_target} ({lang_code})...")
    input_file = "FoodTracker/recipes.json"
    output_file = f"FoodTracker/recipes_{lang_code}.json"
    
    if not os.path.exists(input_file):
        print(f"File not found: {input_file}")
        return
        
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            try:
                translated_data = json.load(f)
            except:
                translated_data = []
    else:
        translated_data = []
        
    start_idx = len(translated_data)
    
    for i in range(start_idx, len(data)):
        item = data[i]
        print(f"  [{i+1}/{len(data)}] Translating recipe: {item['title']}")
        
        item['title'] = translate_text(item['title'], lang_target)
        item['description'] = translate_text(item['description'], lang_target)
        
        if 'tags' in item:
            item['tags'] = [translate_text(t, lang_target) for t in item['tags']]
            
        for ing in item.get('ingredients', []):
            ing['name'] = translate_text(ing['name'], lang_target)
            ing['amount'] = translate_text(ing['amount'], lang_target)
            
        if 'directions' in item:
            item['directions'] = [translate_text(d, lang_target) for d in item['directions']]
            
        translated_data.append(item)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(translated_data, f, ensure_ascii=False, indent=2)

def translate_academy(lang_code, lang_target):
    print(f"\n🌍 Translating academy.json to {lang_target} ({lang_code})...")
    input_file = "FoodTracker/academy.json"
    output_file = f"FoodTracker/academy_{lang_code}.json"
    
    if not os.path.exists(input_file):
        print(f"File not found: {input_file}")
        return
        
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            try:
                translated_data = json.load(f)
            except:
                translated_data = []
    else:
        translated_data = []
        
    start_idx = len(translated_data)
    
    for i in range(start_idx, len(data)):
        course = data[i]
        print(f"  [{i+1}/{len(data)}] Translating course: {course['title']}")
        
        course['title'] = translate_text(course['title'], lang_target)
        
        for article in course.get('articles', []):
            print(f"    -> Article: {article['title']}")
            article['title'] = translate_text(article['title'], lang_target)
            article['subtitle'] = translate_text(article['subtitle'], lang_target)
            article['content'] = translate_text(article['content'], lang_target)
            
        translated_data.append(course)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(translated_data, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    print("🚀 Starting JSON Translation Process (Free Google API)...")
    for code, target in TARGET_LANGS.items():
        translate_recipes(code, target)
        translate_academy(code, target)
    print("\n✅ All JSON translations completed successfully!")
