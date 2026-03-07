#!/usr/bin/env python3
import os

def count_lines_in_file(filepath):
    """Подсчитывает количество строк в файле"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return sum(1 for _ in f)
    except Exception as e:
        print(f"Ошибка при чтении файла {filepath}: {e}")
        return 0

def main():
    total_lines = 0
    
    # Читаем список файлов из dart_files.txt
    try:
        with open('dart_files.txt', 'r', encoding='cp1251') as f:
            content = f.read()
            # Фильтруем только строки, которые заканчиваются на .dart
            files = [line.strip() for line in content.splitlines() if line.strip().endswith('.dart')]
    except Exception as e:
        print(f"Ошибка при чтении dart_files.txt: {e}")
        return
    
    # Подсчитываем строки в каждом файле
    for filepath in files:
        if filepath.strip():  # Пропускаем пустые строки
            lines = count_lines_in_file(filepath)
            total_lines += lines
            print(f"{filepath}: {lines} строк")
    
    print(f"\nОбщее количество строк в проекте: {total_lines}")

if __name__ == "__main__":
    main()