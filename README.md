# ai-project

Скрипт для обезличивания CSV через Microsoft Presidio (Analyzer + Anonymizer в Docker).

## Почему выходной файл становится слишком маленьким

Частая причина: скрипт продолжает обработку, даже когда `localhost:5001`/`localhost:5002` недоступны. Тогда ячейки заполняются пустыми значениями, и итоговый CSV получается на порядки меньше исходного.

Дополнительные причины:
- неверный разделитель CSV (`;` vs `,`),
- проблемы с кодировкой (кириллица отображается как `????` в консоли),
- экспорт без проверки ошибок API.

## Исправленный скрипт

Используйте `scripts/anonymize_presidio.ps1`.

Что исправлено:
- проверка доступности `http://localhost:5001/docs` и `http://localhost:5002/docs` до старта;
- `try/catch` вокруг вызовов Presidio;
- если API вернул ошибку — сохраняется исходный текст (данные не пропадают);
- явные `-Delimiter` и `-Encoding UTF8` на `Import-Csv` и `Export-Csv`.

## Быстрый запуск (Windows PowerShell)

```powershell
# 1) Поднимите контейнеры (пример)
docker compose up -d

# 2) Запустите скрипт
powershell -ExecutionPolicy Bypass -File .\scripts\anonymize_presidio.ps1 `
  -InputFile "D:\Data\input.csv" `
  -OutputFile "D:\Data\input_anon.csv" `
  -Delimiter ";" `
  -Language "ru"
```

## Проверка результата

```powershell
Get-Item D:\Data\input.csv, D:\Data\input_anon.csv | Select Name,Length,LastWriteTime
Get-Content D:\Data\input_anon.csv -TotalCount 5
```

## Если в консоли всё равно `????`

Это обычно отображение, а не порча файла. Проверьте файл в редакторе с UTF-8 (VS Code/Notepad++), либо в PowerShell перед выводом выполните:

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```
