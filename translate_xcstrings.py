import json
import urllib.request
import urllib.parse
import re
import time

TARGET_LANGS = ['ru', 'de', 'es', 'fr', 'it', 'pt-PT']
FILE_PATH = "Localizable.xcstrings"

# Map pt-PT to pt for Google Translate
LANG_MAP = {
    'pt-PT': 'pt'
}

def translate(text, target_lang):
    gt_lang = LANG_MAP.get(target_lang, target_lang)
    
    # Extract placeholders like %@, %lld, %.1f, %1$@
    placeholders = re.findall(r'%[0-9\$]*[\.\d]*[a-zA-Z@]', text)
    temp_text = text
    for i, p in enumerate(placeholders):
        temp_text = temp_text.replace(p, f"__{i}__")
        
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={gt_lang}&dt=t&q={urllib.parse.quote(temp_text)}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            res = json.loads(response.read().decode())
            translated_text = "".join([t[0] for t in res[0] if t[0]])
            
            # Restore placeholders
            for i, p in enumerate(placeholders):
                translated_text = translated_text.replace(f"__{i}__", p)
            return translated_text
    except Exception as e:
        print(f"Error translating '{text}': {e}")
        return text

def main():
    with open(FILE_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    strings = data.get("strings", {})
    count = 0
    
    # Process only a subset of strings if it's too large, but here we process all missing
    for key, val in strings.items():
        if not key.strip() or len(key) < 2 and not key.isalpha():
            continue # skip empty or very short symbol-only keys
            
        localizations = val.get("localizations", {})
        
        for lang in TARGET_LANGS:
            if lang not in localizations:
                print(f"Translating for {lang}: '{key}'")
                translated = translate(key, lang)
                if translated:
                    localizations[lang] = {
                        "stringUnit": {
                            "state": "translated",
                            "value": translated
                        }
                    }
                    count += 1
                    time.sleep(0.2) # small delay to prevent rate limit
        val["localizations"] = localizations
        
    with open(FILE_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        
    print(f"\nDone! Translated {count} missing strings.")

if __name__ == '__main__':
    main()
