#!/bin/bash

# Название временного файла
TEMP_FILE="foodtracker_code.tmp"
> "$TEMP_FILE"

echo "🔍 Сбор кода FoodTracker (Swift + Конфиги)..."

# 1. Конфигурационные файлы
# Мы ищем их в корне и в основной папке проекта
CONFIG_FILES=(
    "README.md"
    "FoodTracker/Info.plist"
    "FoodTracker/FoodTracker.entitlements"
)

files_to_read=""

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        files_to_read="$files_to_read$file"$'\n'
    fi
done

# 2. Поиск всех .swift файлов внутри папки FoodTracker
if [ -d "FoodTracker" ]; then
    # Ищем файлы, исключая скрытые папки (типа .git)
    src_code=$(find FoodTracker -type f -name '*.swift' -not -path "*/.*" 2>/dev/null)
    if [ -n "$src_code" ]; then
        files_to_read="$files_to_read$src_code"$'\n'
    fi
else
    echo "❌ Ошибка: Папка 'FoodTracker' не найдена в текущей директории."
    exit 1
fi

# 3. Чтение файлов и запись в общий файл
echo "$files_to_read" | sed '/^\s*$/d' | while IFS= read -r file; do
    if [ -f "$file" ]; then
        echo "📄 Добавляю: $file"
        echo -e "\n============================================================" >> "$TEMP_FILE"
        echo "FILE: $file" >> "$TEMP_FILE"
        echo -e "============================================================\n" >> "$TEMP_FILE"
        cat "$file" >> "$TEMP_FILE"
    fi
done

# 4. Копирование в буфер обмена (для macOS)
if command -v pbcopy > /dev/null; then
    cat "$TEMP_FILE" | pbcopy
    echo "✅ Весь код скопирован в буфер обмена!"
else
    echo "✅ Готово. Результат сохранен в: $TEMP_FILE"
fi

# Удаление временного файла
rm "$TEMP_FILE"
