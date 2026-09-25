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
- Создание комнаты и вход по коду
- Игра до 4 игроков за столом, живое обновление хода и стола через ActionCable
- Полный набор карт Uno: числа, skip, reverse, +2, wild, +4
- Правило «UNO!» — штраф +2 карты, если игрок не нажал кнопку при последней карте
- Анимации раздачи, сброса и хода карт

## Схема данных

**users** — id, name, email, password_digest, created_at, updated_at

**games** — id, code (уникальный код комнаты), status (waiting/playing/finished), current_player_id → players.id, direction (clockwise/counterclockwise), top_card (jsonb), deck_state (jsonb), winner_id → users.id (nullable), created_at, updated_at

**players** — id, game_id → games.id, user_id → users.id, position, hand (jsonb, массив карт), has_called_uno, created_at, updated_at

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
  channels/       # ActionCable-каналы (синхронизация игры)
  controllers/
  models/         # User, Game, Player
  javascript/     # Stimulus-контроллеры, анимации
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
