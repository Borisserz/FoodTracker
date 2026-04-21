#!/bin/bash

# Скрипт для умного удаления комментариев из .swift файлов
# Останавливаем выполнение при ошибках
set -e

# Если папка не передана как аргумент, используем текущую (.)
TARGET_DIR="${1:-.}"

echo "🚀 Запуск умной очистки комментариев в папке: $TARGET_DIR"
echo "⚠️  ВНИМАНИЕ: Убедись, что ты сделал COMMIT в Git перед запуском!"
read -p "Нажми Enter, чтобы продолжить, или Ctrl+C для отмены..."

# Ищем все файлы .swift и передаем их во встроенный Python скрипт
find "$TARGET_DIR" -type f -name "*.swift" | while read -r file; do
    python3 -c '
import sys, re

def process_swift(code):
    result = []
    i = 0
    n = len(code)
    
    in_string = False
    in_multiline_string = False
    comment_depth = 0
    in_single_comment = False

    while i < n:
        # 1. Обработка однострочных комментариев (включая ///)
        if in_single_comment:
            if code[i] == "\n":
                in_single_comment = False
                result.append("\n")
            i += 1
            continue

        # 2. Обработка многострочных комментариев (включая вложенные /* /* */ */)
        if comment_depth > 0:
            if i + 1 < n and code[i:i+2] == "/*":
                comment_depth += 1
                i += 2
            elif i + 1 < n and code[i:i+2] == "*/":
                comment_depth -= 1
                i += 2
            else:
                # Сохраняем переносы строк внутри многострочных комментов, чтобы не сбивать нумерацию (опционально)
                if code[i] == "\n":
                    pass 
                i += 1
            continue

        # 3. Обработка многострочных строк """..."""
        if in_multiline_string:
            result.append(code[i])
            if i + 2 < n and code[i:i+3] == "\"\"\"" and code[i-1] != "\\":
                result.append("\"\"")
                in_multiline_string = False
                i += 3
                continue
            i += 1
            continue

        # 4. Обработка обычных строк "..."
        if in_string:
            result.append(code[i])
            if code[i] == "\"" and code[i-1] != "\\":
                in_string = False
            i += 1
            continue

        # --- Проверка НАЧАЛА новых блоков ---

        # Начало многострочной строки
        if i + 2 < n and code[i:i+3] == "\"\"\"":
            in_multiline_string = True
            result.append("\"\"\"")
            i += 3
            continue

        # Начало обычной строки
        if code[i] == "\"":
            in_string = True
            result.append("\"")
            i += 1
            continue

        # Начало однострочного комментария
        if i + 1 < n and code[i:i+2] == "//":
            in_single_comment = True
            i += 2
            continue

        # Начало многострочного комментария
        if i + 1 < n and code[i:i+2] == "/*":
            comment_depth += 1
            i += 2
            continue

        # Если это обычный код — просто добавляем его
        result.append(code[i])
        i += 1

    # Постобработка: очистка мусора
    cleaned = "".join(result)
    # Удаляем пробелы в конце строк
    cleaned = re.sub(r"[ \t]+$", "", cleaned, flags=re.MULTILINE)
    # Заменяем 3 и более пустых строк подряд на 2 пустые (чтобы код остался красивым)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    
    # Удаляем пустые строки в самом начале файла
    cleaned = cleaned.lstrip()
    
    return cleaned

file_path = sys.argv[1]

# Читаем оригинальный файл
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()

# Очищаем
new_code = process_swift(code)

# Записываем обратно
with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_code)

' "$file"
    echo "✅ Очищен: $file"
done

echo "🎉 Готово! Все комментарии успешно удалены."