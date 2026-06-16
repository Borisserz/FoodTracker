import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Array appends
    content = re.sub(r'([a-zA-Z0-9_]+)\.meals\.append\(([^)]+)\)', r'\1.meals = (\1.meals ?? []) + [\2]', content)
    content = re.sub(r'([a-zA-Z0-9_]+)\.beverages\.append\(([^)]+)\)', r'\1.beverages = (\1.beverages ?? []) + [\2]', content)
    content = re.sub(r'([a-zA-Z0-9_]+)\.activities\.append\(([^)]+)\)', r'\1.activities = (\1.activities ?? []) + [\2]', content)
    content = re.sub(r'([a-zA-Z0-9_]+)\.foodItems\.append\(([^)]+)\)', r'\1.foodItems = (\1.foodItems ?? []) + [\2]', content)
    
    # append(contentsOf: ...)
    content = re.sub(r'([a-zA-Z0-9_]+)\.foodItems\.append\(contentsOf:\s*([^)]+)\)', r'\1.foodItems = (\1.foodItems ?? []) + \2', content)

    # .firstIndex, .first, .filter, .reduce, .map, .flatMap, .isEmpty, .last
    methods = ['firstIndex', 'first', 'filter', 'reduce', 'map', 'flatMap', 'isEmpty', 'last', 'removeAll', 'remove']
    for method in methods:
        content = re.sub(r'([a-zA-Z0-9_]+)\.meals\.' + method, r'(\1.meals ?? []).' + method, content)
        content = re.sub(r'([a-zA-Z0-9_]+)\.beverages\.' + method, r'(\1.beverages ?? []).' + method, content)
        content = re.sub(r'([a-zA-Z0-9_]+)\.activities\.' + method, r'(\1.activities ?? []).' + method, content)
        content = re.sub(r'([a-zA-Z0-9_]+)\.foodItems\.' + method, r'(\1.foodItems ?? []).' + method, content)

    # ForEach(meal.foodItems) -> ForEach(meal.foodItems ?? [])
    content = re.sub(r'ForEach\(([a-zA-Z0-9_]+)\.meals\)', r'ForEach(\1.meals ?? [])', content)
    content = re.sub(r'ForEach\(([a-zA-Z0-9_]+)\.foodItems\)', r'ForEach(\1.foodItems ?? [])', content)

    # for x in meal.foodItems {
    content = re.sub(r'in ([a-zA-Z0-9_]+)\.meals \{', r'in (\1.meals ?? []) {', content)
    content = re.sub(r'in ([a-zA-Z0-9_]+)\.foodItems \{', r'in (\1.foodItems ?? []) {', content)
    content = re.sub(r'in ([a-zA-Z0-9_]+)\.meals$', r'in (\1.meals ?? [])', content, flags=re.MULTILINE)
    content = re.sub(r'in ([a-zA-Z0-9_]+)\.foodItems$', r'in (\1.foodItems ?? [])', content, flags=re.MULTILINE)

    if original != content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('/Users/borisserzhanovich/projects/FoodTracker'):
    for file in files:
        if file.endswith('.swift'):
            process_file(os.path.join(root, file))
