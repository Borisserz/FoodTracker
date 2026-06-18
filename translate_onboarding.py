import re
import os

files = {
    "FoodTracker/App/MonetkaOnboarding1.swift": {
        r'"Наполни себя энергией 🌱"': r'"Energize yourself 🌱"',
        r'"Мы — это то, что мы едим и пьем\. Начни свой путь к осознанному питанию, следи за водным балансом и наполняй тело витаминами каждый день\. Твое здоровье — твоя главная инвестиция!"': r'"We are what we eat and drink. Start your journey to mindful eating, track your water balance, and nourish your body every day. Your health is your greatest investment!"',
        r'"Продолжить с Apple"': r'"Continue with Apple"',
        r'"Быстрый вход"': r'"Quick login"',
        r'"Продолжить с Google"': r'"Continue with Google"',
        r'"Регистрация через Google"': r'"Sign up with Google"',
        r'"Остаться гостем"': r'"Continue as Guest"',
        r'"Войти как гость\?"': r'"Continue as guest?"',
        r'"Если остаться гостем, данные о вашем питании, калориях и водном балансе не будут сохраняться в облаке\. При смене устройства вы потеряете дневник\."': r'"If you continue as a guest, your nutrition, calories, and water balance data will not be saved in the cloud. You will lose your diary if you change devices."',
        r'"Почему лучше зарегистрироваться:"': r'"Why you should sign up:"',
        r'"Сохранение дневника питания"': r'"Save your food diary"',
        r'"Трекинг выпитой воды на всех устройствах"': r'"Track water intake across devices"',
        r'"Персональные рецепты и рекомендации"': r'"Personalized recipes and recommendations"',
        r'"Гость"': r'"Guest"',
        r'"Войти"': r'"Log in"',
        r'"Назад"': r'"Back"',
        r'"Регистрация"': r'"Sign up"',
        r'"Заполни данные, чтобы сохранить свой прогресс в питании и получить персональные рекомендации\."': r'"Fill in your details to save your nutrition progress and get personalized recommendations."',
        r'"Имя и фамилия"': r'"Full name"',
        r'"Пароль"': r'"Password"',
        r'"Зарегистрироваться"': r'"Sign up"',
        r'"Нажимая «Зарегистрироваться», вы принимаете условия использования и политику конфиденциальности\."': r'"By tapping Sign up, you agree to our Terms of Use and Privacy Policy."'
    },
    "FoodTracker/App/MonetkaOnboarding2.swift": {
        r'"Пока не выбрано"': r'"Not selected yet"',
        r'"Офисный дзен"': r'"Office zen"',
        r'"Легкий тонус"': r'"Light tone"',
        r'"Активный метаболизм"': r'"Active metabolism"',
        r'"Турбо-режим"': r'"Turbo mode"',
        r'"Сидячая работа, минимум шагов"': r'"Sedentary job, minimum steps"',
        r'"Прогулки, йога 1-2 раза в неделю"': r'"Walking, yoga 1-2 times a week"',
        r'"Спорт 3-4 раза, регулярное движение"': r'"Sports 3-4 times, regular movement"',
        r'"Ежедневные нагрузки, высокий расход калорий"': r'"Daily workouts, high calorie burn"',
        r'"Твое\\nЧистое\\nТопливо\."': r'"Your\nClean\nFuel."',
        r'"Твой персональный нутрициолог\. Никаких жестких диет и голодовок — только умный подход к телу и балансу энергии\.\\n\\nГотов изменить себя изнутри\?"': r'"Your personal nutritionist. No strict diets or starving — just a smart approach to your body and energy balance.\n\nReady to transform yourself from the inside out?"',
        r'"Начать"': r'"Start"',
        r'"Оцифруй себя"': r'"Digitize yourself"',
        r'"Базовые параметры для старта"': r'"Basic metrics to start"',
        r'"Возраст"': r'"Age"',
        r'"лет"': r'"years"',
        r'"Рост"': r'"Height"',
        r'"см"': r'"cm"',
        r'"Вес"': r'"Weight"',
        r'"кг"': r'"kg"',
        r'"Алгоритм использует эти данные для точного расчета BMR \(базового обмена веществ\) и твоей дневной нормы макронутриентов\."': r'"The algorithm uses this data to accurately calculate your BMR (Basal Metabolic Rate) and your daily macronutrient needs."',
        r'"Продолжить"': r'"Continue"',
        r'"Твой ритм"': r'"Your rhythm"',
        r'"Сколько энергии ты тратишь в течение дня\?"': r'"How much energy do you burn during the day?"',
        r'"Синтезировать план"': r'"Synthesize plan"',
        r'"План сгенерирован"': r'"Plan generated"',
        r'"Твоя суточная норма калорий и макронутриентов успешно рассчитана\.\\n\\nДобро пожаловать в лучшую версию себя\."': r'"Your daily calorie and macronutrient goals have been successfully calculated.\n\nWelcome to the best version of yourself."',
        r'"Запустить синтез"': r'"Launch synthesis"'
    },
    "FoodTracker/Views/AddMealView.swift": {
        r' \|\| nameLower\.contains\("мясо"\) \|\| nameLower\.contains\("стейк"\)': '',
        r' \|\| nameLower\.contains\("рыба"\) \|\| nameLower\.contains\("лосось"\)': ''
    }
}

for filepath, file_translations in files.items():
    if not os.path.exists(filepath): continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for k, v in file_translations.items():
        content = re.sub(k, v, content)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done translating onboarding.")
