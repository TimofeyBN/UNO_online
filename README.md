# Uno Online

Веб-приложение для игры в Uno в реальном времени. Несколько игроков собираются в одной комнате и играют партию прямо в браузере — без установки чего-либо, с живым обновлением стола у всех участников.

## Стек

| Слой | Технология |
|---|---|
| Backend | Ruby on Rails |
| Реалтайм | ActionCable (WebSocket) |
| Frontend | JS (Stimulus / ванильный JS), CSS-анимации, GSAP для сложных переходов карт |
| БД | PostgreSQL |

## Возможности

- Регистрация и авторизация (email/пароль, реализовано вручную, без Devise)
- Публичные и приватные комнаты — публичные видны в списке на главной, приватные доступны только по коду
- Настройка комнаты при создании: видимость и лимит игроков (2–6)
- Статусы комнаты: ожидание / идёт игра / завершена — видны и на главной, и в лобби
- Система готовности — у каждого игрока свой флаг «Готов», партия стартует автоматически, когда готовы все (от 2 игроков)
- Создатель комнаты может её удалить; если выходит сам — право хоста переходит следующему игроку; если уходят все — комната удаляется
- Если во время игры остался один игрок — он побеждает техническим поражением соперников, комната возвращается в лобби
- Витрина UI-kit (`/ui-kit`) — переиспользуемые компоненты интерфейса
- Полный набор карт Uno: числа, skip, reverse, +2, wild, +4 *(пока только в схеме данных, игровая логика не реализована)*
- Правило «UNO!» — штраф +2 карты, если игрок не нажал кнопку при последней карте *(пока только в схеме данных)*
- Живое обновление данных — пока реализовано через периодический опрос (перезагрузка лобби раз в 3 сек), заменится на ActionCable на следующем этапе

## Схема данных

**users** — id, name, email, password_digest, created_at, updated_at

**games** — id, code (уникальный код комнаты), status (waiting/playing/finished), visibility (public/private), max_players (2–6), host_id → users.id (создатель комнаты), current_player_id → players.id, direction (clockwise/counterclockwise), top_card (jsonb), deck_state (jsonb), winner_id → users.id (nullable), created_at, updated_at

**players** — id, game_id → games.id, user_id → users.id, position, hand (jsonb, массив карт), ready (готовность в лобби), has_called_uno, created_at, updated_at

Формат карты: `{ "color": "red|yellow|green|blue|null", "value": "0-9|skip|reverse|draw2|wild|wild_draw4" }`

Ограничения уникальности: `(game_id, user_id)`, `(game_id, position)`, `code` у games.

## Установка и запуск

```bash
git clone https://github.com/TimofeyBN/UNO_online.git
cd UNO_online

# зависимости
bundle install

set DISABLE_BOOTSNAP=1

# база данных
bundle exec rails db:create
bundle exec rails db:migrate

# запуск
bundle exec rails server
```

Приложение будет доступно на `http://127.0.0.1:3000/`.

## Структура проекта

```
app/
  channels/       # ActionCable-каналы (синхронизация игры) — на следующем этапе
  controllers/     # games, sessions, registrations, pages (UI-kit)
  models/         # User, Game, Player
  javascript/     # Stimulus-контроллеры (включая lobby_poll — временный опрос)
  views/
config/
db/
  migrate/
```

## Этапы разработки

1. Модели, миграции, авторизация
2. Лобби и создание/вход в комнату
3. Базовая логика игры без анимаций
4. ActionCable — синхронизация ходов между игроками
5. Анимации и полировка UI
6. Спецкарты и edge-кейсы

## Авторы

Тимофей Батраков — TimofeyBN
