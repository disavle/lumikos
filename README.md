# Lumikos

**English** · [Русский](#русский)

A small iOS app for movies and series. Swipe recommendation cards like in Tinder: right adds a title to your list, left skips it. In the list you pin what you are watching now, check off episodes and rate titles with one of five emoji.

> This is a **learning project**: a compact tour of the modern iOS stack for a developer coming from UIKit. It was made with [Claude Code Projects](https://claude.ai/code). Start reading at [docs/TOUR.md](docs/TOUR.md).

**Lumikos** = *lumi* (Finnish "snow") + *kos* (Norwegian "cozy"): a warm winter evening with a movie.

## Stack

| | |
|---|---|
| UI | SwiftUI screens, `@Observable` view models (MVVM), UIKit coordinators with `UIHostingController` |
| Concurrency | async/await, one `actor` (`FeedLoader`), Swift 6 language mode |
| Data | URLSession + Codable (2 files), `URLCache`, SwiftData offline copy, Keychain |
| Combine | `NetworkMonitor`: `NWPathMonitor` → `CurrentValueSubject` → `for await` |
| Other | String Catalog (en + ru), Swift Testing, Maestro UI flow |
| Tools | Tuist (one app target), mise, fastlane, GitHub Actions |
| Server | Vapor + Fluent: a BFF over [TMDB](https://www.themoviedb.org), email + nickname + password login (Bcrypt), Postgres on Neon, Render |

## Run it

Requirements: Xcode 26, [mise](https://mise.jdx.dev), a free [TMDB API Read Access Token](https://www.themoviedb.org/settings/api).

```bash
cp Backend/.env.example Backend/.env   # paste your TMDB token there
mise run api                          # terminal 1: server on http://localhost:8080 (SQLite file)
mise run generate                     # terminal 2: creates Lumikos.xcodeproj and opens Xcode
```

Run the `Lumikos` scheme in a simulator and sign up. The simulator talks to `localhost`, a real iPhone to the server on Render.

Tests: `mise run test` (iOS + server), UI flow: `maestro test .maestro`.

## Where the keys live

No secrets are in this repository.

| Key | Where | Used by |
|---|---|---|
| `TMDB_TOKEN` | Render → Environment; locally `Backend/.env` | server |
| `DATABASE_URL` | Render → Environment (Neon connection string) | server |
| `RENDER_DEPLOY_HOOK` | GitHub → Settings → Secrets → Actions | CI |
| user token | iPhone Keychain | app |

Deploy: every push to `main` builds `ghcr.io/disavle/lumikos-backend` and asks Render to run it (`.github/workflows/ci.yml`).

## License

MIT

---

## Русский

Небольшое iOS-приложение для фильмов и сериалов. Свайпаешь карточки рекомендаций как в Tinder: вправо добавить в список, влево пропустить. В списке закрепляешь то, что смотришь сейчас, отмечаешь серии и ставишь оценку одним из пяти эмодзи.

> Это **учебный проект**: компактная экскурсия по современному iOS-стеку для разработчика, который пришёл из UIKit. Сделан в [Claude Code Projects](https://claude.ai/code). Начни с [docs/TOUR.md](docs/TOUR.md).

**Lumikos** = *lumi* (фин. «снег») + *kos* (норв. «уютно»): тёплый зимний вечер с фильмом.

## Запуск

Нужны Xcode 26, [mise](https://mise.jdx.dev) и бесплатный [TMDB API Read Access Token](https://www.themoviedb.org/settings/api).

```bash
cp Backend/.env.example Backend/.env   # вставь туда токен TMDB
mise run api                          # терминал 1: сервер на http://localhost:8080 (файл SQLite)
mise run generate                     # терминал 2: создаёт Lumikos.xcodeproj и открывает Xcode
```

Запусти схему `Lumikos` в симуляторе и зарегистрируйся. Симулятор ходит на `localhost`, настоящий iPhone на сервер в Render.

Тесты: `mise run test` (iOS и сервер), UI-сценарий: `maestro test .maestro`.

## Где лежат ключи

В репозитории секретов нет.

| Ключ | Где | Кто читает |
|---|---|---|
| `TMDB_TOKEN` | Render → Environment; локально `Backend/.env` | сервер |
| `DATABASE_URL` | Render → Environment (строка подключения Neon) | сервер |
| `RENDER_DEPLOY_HOOK` | GitHub → Settings → Secrets → Actions | CI |
| токен пользователя | Keychain на iPhone | приложение |

Деплой: каждый пуш в `main` собирает `ghcr.io/disavle/lumikos-backend` и просит Render его запустить (`.github/workflows/ci.yml`).

## Лицензия

MIT
