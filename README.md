# Test Lab

Отдельная лаборатория системных тестов Portable Agent. Она не знает бизнес-правил и проверяет
общие свойства платформы: доступность, задержку, обработку ошибок и восстановление.

## Быстрый старт

```powershell
Copy-Item .env.example .env
pwsh ./scripts/check.ps1
pwsh ./scripts/run-load.ps1
```

По умолчанию Compose поднимает только локальный fake-service. Для внешней среды явно передай
`TARGET_URL`; production URL скрипты отклоняют. Пороги k6 хранятся рядом со сценарием.

