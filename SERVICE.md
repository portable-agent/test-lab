# Карточка репозитория

| Поле | Значение |
|---|---|
| Ответственность | acceptance-, системные, load и resilience-тесты |
| Бизнес-код | отсутствует |
| Основной инструмент | k6; contract-first сценарии |
| Chaos | отдельный ручной запуск, выключен по умолчанию |
| Первый acceptance-путь | Channel Gateway → Conversation Service → Agent Runtime → Widget decision через Channel Gateway → Action Service → Temporal → Calendar MCP |
| Локальный запуск | `task test:e2e` против уже поднятого окружения |
| Проверка AI-модели | `task test:model` против model-профиля; не входит в обычный CI |
| Проверка внешнего подключения | `task test:connection`: виджет Google Calendar, state, PKCE и свежая OAuth-ссылка |
| Граница ответственности | Не поднимает сервисы и не содержит их component-тесты |

