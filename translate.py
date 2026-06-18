import json
import os
import time
from deep_translator import GoogleTranslator

LANGUAGES = {
    "fr": "fr",
    "de": "de",
    "it": "it",
    "pt-PT": "pt",
    "ru": "ru",
    "es": "es"
}

def translate_batch(texts_list, target_lang_code):
    translator = GoogleTranslator(source='en', target=target_lang_code)
    try:
        # deep-translator supports translate_batch
        translated = translator.translate_batch(texts_list)
        return translated
    except Exception as e:
        print(f"Error translating to {target_lang_code}: {e}")
        return None

def main():
    xcstrings_path = "Localizable.xcstrings"
    with open(xcstrings_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    strings = data.get("strings", {})
    
    for lang_code, google_lang in LANGUAGES.items():
        missing_keys = []
        
        for key, value in strings.items():
            if not key.strip(): continue
            if "%" in key and len(key) < 5: continue # skip simple symbol templates
            
            localizations = value.get("localizations", {})
            lang_entry = localizations.get(lang_code, {})
            
            if "variations" in lang_entry:
                continue
            
            if "stringUnit" not in lang_entry or lang_entry["stringUnit"].get("state") != "translated":
                missing_keys.append(key)
                
        if not missing_keys:
            print(f"Language {lang_code} is already 100%")
            continue
            
        print(f"Found {len(missing_keys)} missing for {lang_code}")
        
        # Google Translate limits batch sizes implicitly by URL length, let's use small batches
        batch_size = 20
        for i in range(0, len(missing_keys), batch_size):
            batch_keys = missing_keys[i:i+batch_size]
            print(f"Translating {lang_code} batch {i//batch_size + 1}/{len(missing_keys)//batch_size + 1}...")
            
            translated_list = translate_batch(batch_keys, google_lang)
            
            if translated_list and len(translated_list) == len(batch_keys):
                for j, key in enumerate(batch_keys):
                    translated_text = translated_list[j]
                    if translated_text:
                        # Fix up variables if google translate messed them up
                        translated_text = translated_text.replace("% lld", "%lld").replace("% @", "%@").replace("% ld", "%ld").replace("％", "%")
                        
                        if "localizations" not in strings[key]:
                            strings[key]["localizations"] = {}
                        
                        strings[key]["localizations"][lang_code] = {
                            "stringUnit": {
                                "state": "translated",
                                "value": translated_text
                            }
                        }
                with open(xcstrings_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
            else:
                print("Failed to translate batch or size mismatch.")
            time.sleep(0.5)
            
    print("All done!")

if __name__ == "__main__":
    main()
