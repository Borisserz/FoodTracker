const fs = require('fs');
const path = require('path');

const targetLangs = {
  'de': 'German',
  'es': 'Spanish',
  'fr': 'French',
  'it': 'Italian',
  'pt-PT': 'pt', // Google translate uses pt
  'ru': 'Russian'
};

async function translateText(text, targetLang) {
    if (!text || text.trim() === '') return text;
    
    // Replace %lld, %1$@ etc with placeholder to prevent translation corruption
    let placeholders = [];
    let cleanText = text.replace(/(%[0-9\$]*[a-zA-Z\@])/g, (match) => {
        placeholders.push(match);
        return `__PH${placeholders.length - 1}__`;
    });

    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${targetLang}&dt=t&q=${encodeURIComponent(cleanText)}`;
    
    try {
        const response = await fetch(url);
        const json = await response.json();
        let translated = '';
        if (json && json[0]) {
            json[0].forEach(part => {
                if (part[0]) translated += part[0];
            });
        }
        
        // Restore placeholders
        placeholders.forEach((ph, i) => {
            translated = translated.replace(`__PH${i}__`, ph);
        });
        
        return translated || text;
    } catch (e) {
        console.error("Translation error:", e.message);
        return text;
    }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function processXcstrings() {
  const filePath = path.join(__dirname, 'Localizable.xcstrings');
  console.log(`Loading ${filePath}...`);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  
  // Clean up English states while we're at it
  for (const [key, entry] of Object.entries(data.strings)) {
    if (entry.localizations && entry.localizations['en']) {
        entry.localizations['en'].stringUnit.state = 'translated';
    }
  }

  for (const [langCode, langName] of Object.entries(targetLangs)) {
    const glang = langCode === 'pt-PT' ? 'pt' : langCode;
    let missingCount = 0;
    
    for (const [key, entry] of Object.entries(data.strings)) {
      if (!entry.localizations) entry.localizations = {};
      const loc = entry.localizations[langCode];
      
      if (!loc || loc.stringUnit.state !== 'translated') {
        if (key.trim().length > 0) {
            console.log(`Translating to ${langCode}: ${key}`);
            const translatedText = await translateText(key, glang);
            
            data.strings[key].localizations[langCode] = {
              stringUnit: {
                state: 'translated',
                value: translatedText
              }
            };
            missingCount++;
            await sleep(300); // polite delay
        }
      }
    }
    
    console.log(`Finished ${missingCount} translations for ${langCode}`);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf8');
  }
  
  console.log("Finished Localizable.xcstrings");
}

async function processJSONs() {
    const recipesBase = JSON.parse(fs.readFileSync(path.join(__dirname, 'FoodTracker/recipes.json'), 'utf8'));
    const academyBase = JSON.parse(fs.readFileSync(path.join(__dirname, 'FoodTracker/academy.json'), 'utf8'));

    for (const [langCode, langName] of Object.entries(targetLangs)) {
        const glang = langCode === 'pt-PT' ? 'pt' : langCode;
        
        // Recipes
        const rPath = path.join(__dirname, `FoodTracker/recipes_${langCode}.json`);
        let recipesLang = [];
        if (fs.existsSync(rPath)) recipesLang = JSON.parse(fs.readFileSync(rPath, 'utf8'));
        
        for (let i = 0; i < recipesBase.length; i++) {
            const baseItem = recipesBase[i];
            let langItem = recipesLang.find(r => r.id === baseItem.id);
            if (!langItem) {
                langItem = { id: baseItem.id };
                recipesLang.push(langItem);
            }
            
            if (!langItem.title || langItem.title === baseItem.title) langItem.title = await translateText(baseItem.title, glang);
            if (!langItem.dietType || langItem.dietType === baseItem.dietType) langItem.dietType = await translateText(baseItem.dietType, glang);
            
            if (!langItem.ingredients || langItem.ingredients.length === 0) {
                langItem.ingredients = [];
                for (const ing of baseItem.ingredients) {
                    langItem.ingredients.push({
                        name: await translateText(ing.name, glang),
                        amount: await translateText(ing.amount, glang)
                    });
                }
            }
            
            langItem.imageUrl = baseItem.imageUrl;
            langItem.caloriesPerServing = baseItem.caloriesPerServing;
            langItem.protein = baseItem.protein;
            langItem.fat = baseItem.fat;
            langItem.carbs = baseItem.carbs;
            langItem.time = baseItem.time;
        }
        fs.writeFileSync(rPath, JSON.stringify(recipesLang, null, 2), 'utf8');

        // Academy
        const aPath = path.join(__dirname, `FoodTracker/academy_${langCode}.json`);
        let academyLang = [];
        if (fs.existsSync(aPath)) academyLang = JSON.parse(fs.readFileSync(aPath, 'utf8'));
        
        for (let i = 0; i < academyBase.length; i++) {
            const baseItem = academyBase[i];
            let langItem = academyLang.find(a => a.id === baseItem.id);
            if (!langItem) {
                langItem = { id: baseItem.id };
                academyLang.push(langItem);
            }
            
            if (!langItem.title || langItem.title === baseItem.title) langItem.title = await translateText(baseItem.title, glang);
            if (!langItem.description || langItem.description === baseItem.description) langItem.description = await translateText(baseItem.description, glang);
            if (!langItem.content || langItem.content === baseItem.content) langItem.content = await translateText(baseItem.content, glang);
            if (!langItem.category || langItem.category === baseItem.category) langItem.category = await translateText(baseItem.category, glang);
            langItem.imageUrl = baseItem.imageUrl;
            langItem.readTime = baseItem.readTime;
            langItem.isPremium = baseItem.isPremium;
        }
        fs.writeFileSync(aPath, JSON.stringify(academyLang, null, 2), 'utf8');
    }
}

async function run() {
    await processXcstrings();
    await processJSONs();
}

run();
