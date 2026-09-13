# Test Lab

Отдельная лаборатория acceptance- и системных тестов Portable Agent. Она не придумывает
бизнес-правила: продуктовые ожидания берутся из документации `platform`. Лаборатория также проверяет
общие свойства платформы: доступность, задержку, обработку ошибок и восстановление.

## Быстрый старт

```powershell
Copy-Item .env.example .env
pwsh ./scripts/check.ps1
pwsh ./scripts/run-load.ps1
```

По умолчанию Compose поднимает только локальный fake-service. Для внешней среды явно передай
`TARGET_URL`; production URL скрипты отклоняют. Пороги k6 хранятся рядом со сценарием.

## Acceptance-тест встречи

`tests/calendar-event.js` описывает первый продуктовый путь: demo-команда создаёт предложение,
действие ждёт подтверждения, после подтверждения завершается и создаёт ровно одно событие. Повтор с
тем же `requestKey` не создаёт дубль.

До появления Temporal worker и `fake-calendar` этот тест намеренно красный. После запуска полного
локального стенда получи JWT тестового пользователя и выполни:

```powershell
$env:ACTION_TOKEN = "<local-test-token с audience agent-runtime и action-service>"
$env:CALENDAR_TEST_API_KEY = "<тот же локальный секрет, что у Calendar MCP>"
pwsh ./scripts/run-calendar.ps1
```

Скрипт принимает только локальные HTTP-адреса. Проверочный API `fake-calendar` доступен только в
тестовом режиме и требует отдельный `X-Test-Key`; секрет не хранится в Git.

Один JWT передаётся в Agent Runtime и Action Service. Оба сервиса независимо проверяют подпись,
issuer, срок и свой audience. Идентификаторы пользователя и tenant не передаются в JSON запроса:
сервисы получают их из проверенных claims `sub` и `tenant_id`.
