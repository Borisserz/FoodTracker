import os
import xml.etree.ElementTree as ET
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
        translated = translator.translate(text)
        return translated
    except Exception as e:
        print(f"❌ Translation error: {e}")
        time.sleep(2)
        return text

def translate_xliff(lang_code, target_code):
    print(f"\n🌍 Processing XLIFF for {lang_code}...")
    
    file_path = f"FoodTracker Localizations/{lang_code}.xcloc/Localized Contents/{lang_code}.xliff"
    if not os.path.exists(file_path):
        print(f"  ❌ File not found: {file_path}")
        return
        
    ET.register_namespace('', "urn:oasis:names:tc:xliff:document:1.2")
    
    tree = ET.parse(file_path)
    root = tree.getroot()
    namespace = {'xliff': 'urn:oasis:names:tc:xliff:document:1.2'}
    
    trans_units = root.findall('.//xliff:trans-unit', namespace)
    total = len(trans_units)
    translated_count = 0
    
    for idx, unit in enumerate(trans_units):
        source = unit.find('xliff:source', namespace)
        target = unit.find('xliff:target', namespace)
        
        if source is None or not source.text:
            continue
            
        if target is not None and target.text and target.text.strip():
            translated_count += 1
            continue
            
        print(f"  [{idx+1}/{total}] Translating: {source.text[:50]}...")
        translated_text = translate_text(source.text, target_code)
        
        if target is None:
            target = ET.SubElement(unit, 'target')
            
        target.text = translated_text
        translated_count += 1
        
        if translated_count % 20 == 0:
            tree.write(file_path, encoding='utf-8', xml_declaration=True)
            
    tree.write(file_path, encoding='utf-8', xml_declaration=True)
    print(f"✅ Finished {lang_code}.xliff!")

if __name__ == "__main__":
    print("🚀 Starting XLIFF Translation Process (Free Google API)...")
    for code, target in TARGET_LANGS.items():
        translate_xliff(code, target)
    print("\n✅ All XLIFF translations completed successfully!")
