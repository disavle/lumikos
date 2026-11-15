# Экскурсия по Lumikos

9 остановок по 20–30 минут. В каждой: что открыть, на что смотреть, чем это отличается от UIKit, и одно маленькое изменение руками. Код приложения читай в Xcode, сервер тоже можно открыть в Xcode (остановка 2).

Карта проекта:

```
Backend/Sources/App/      сервер на Vapor (10 файлов)
Backend/Dockerfile        как сервер упаковывается в образ для Render (остановка 9)
iOS/Project.swift         описание Xcode-проекта для Tuist
iOS/Lumikos/App/          запуск, координаторы, зависимости
iOS/Lumikos/Network/      сеть: APIClient, Endpoint, модели, NetworkMonitor
iOS/Lumikos/Auth/         вход и регистрация, Keychain
iOS/Lumikos/Feed/         вкладка «Для тебя»: свайпы
iOS/Lumikos/List/         вкладка «Мой список» и SwiftData-копия
iOS/Lumikos/Search/       поиск фильмов и сериалов (внутри «Моего списка»)
iOS/Lumikos/Details/      экран деталей и серии
iOS/Lumikos/UI/           постер, эмодзи-оценка, AXID для Maestro
```

Путь запроса от пальца до TMDB и обратно:

```
SwipeCard (жест) → FeedViewModel.swipe → APIClient.send(.saveItem)
  → PUT /list/movie/603 → ListController.upsert → Postgres
FeedView.task → FeedViewModel.loadIfNeeded → actor FeedLoader → GET /feed
  → TitlesController.feed → TMDB trending + recommendations → FeedPage → карточки
```

---

## 1. Запуск: mise, Tuist, Xcode-проект

**Открой:** `mise.toml`, `iOS/Project.swift`.

- **mise** фиксирует версии инструментов (`[tools]`) и хранит короткие команды (`[tasks]`). Как `.nvmrc` + `Makefile` в одном файле.
- **Tuist** генерирует Xcode-проект из Swift-кода. Сгенерированное не лежит в git, значит конфликтов в `project.pbxproj` не бывает. Один таргет приложения и один для тестов (тестам Xcode всегда нужен свой таргет).
- **Что появляется после `mise run generate`:**
  - `Lumikos.xcodeproj` (синий): сам проект, таргеты и настройки.
  - `Lumikos.xcworkspace` (белый): «папка» над проектами и пакетами SPM. **Работай в нём**, его и открывает Tuist. Сейчас внутри один проект, но любая зависимость через `tuist install` попадёт именно сюда.
  - `Derived/`: файлы, которые Tuist пишет сам. `InfoPlists/Lumikos-Info.plist` собран из `infoPlist:` в `Project.swift`, а `Sources/TuistBundle+Lumikos.swift` и похожие дают удобный доступ к ресурсам. Руками их не правь: при следующей генерации всё перезапишется.
- **Адрес сервера:** константа `serverURL` в `Project.swift` → ключ `APIURL` в Info.plist → `AppDependencies.serverURL` читает его при старте. По умолчанию это Render. Для разового запуска на локальный сервер: Edit Scheme → Run → Environment Variables, `API_URL` = `http://localhost:8080`.
- **Было в UIKit:** проект руками в Xcode, `Info.plist` отдельным файлом. **Стало:** `infoPlist: .extendingDefault(with:)` прямо в `Project.swift`. Всё, что касается проекта, меняй там, а не в настройках Xcode.

**Руками:** поменяй `CFBundleDisplayName` в `Project.swift`, выполни `mise run generate` и найди новое значение в `Derived/InfoPlists/Lumikos-Info.plist`.

## 2. Vapor: роуты, модели, миграции, логи

**Открой:** `routes.swift`, `Models/ListItem.swift`, `Controllers/ListController.swift`.

- Роут = путь + async-функция. Возвращаешь `Content`-структуру, Vapor сам делает JSON.
- Fluent-модель: класс с `@ID`, `@Field`, `@Parent`. Миграция рядом: создаёт таблицу. Локально база SQLite-файл, на Render Postgres, код один.
- **Сервер в Xcode:** открой `Backend/Package.swift` (двойной клик или `xed Backend`). Xcode сам скачает пакеты, схема называется `App`. Чтобы сервер нашёл `.env`, укажи папку: Edit Scheme → Run → Options → Working Directory → `Backend`. Дальше обычные брейкпоинты, как в приложении.
- **Токен TMDB локально:** файл `Backend/.env` со строкой `TMDB_TOKEN=eyJ...`. Он в `.gitignore`, Vapor читает его сам при старте.
- **Логи:**
  - Локально всё видно в терминале с `mise run api` (или в консоли Xcode): каждая строка `GET /feed`, ошибки, предупреждение `TMDB ... answered 401`, если токен неверный. Подробнее: `swift run App serve --log debug`.
  - На Render: сервис → **Logs**, там живой хвост тех же строк. Если приложение показывает ошибку, сначала смотри сюда.

**Руками:** добавь в `ListItem` поле `note` (заметка к фильму): `@OptionalField`, колонка в `CreateListItem`, поле в DTO. Удали `Backend/db.sqlite`, перезапусти сервер и проверь `GET /list`.

## 3. BFF: сервер как прослойка над TMDB

**Открой:** `TMDB/TMDB.swift`, `Controllers/TitlesController.swift`.

- BFF (backend for frontend): приложение не знает про TMDB. Сервер прячет токен и превращает большие ответы TMDB в маленькие DTO (`TitleCard`, `TitleDetails`).
- **Язык:** приложение шлёт `Accept-Language` с языком телефона, сервер передаёт TMDB `language=ru-RU` или `en-US`. Названия, описания и жанры приходят на русском, если перевод есть в TMDB. Проверить: Edit Scheme → Run → Options → App Language → Russian.
- `feed`: `withTaskGroup` запрашивает рекомендации для трёх тайтлов **параллельно**, это structured concurrency на сервере.
- `search`: TMDB `search/multi` ищет сразу фильмы, сериалы и людей. Людей отбрасывает `TitleCard.init?`, у них нет подходящего `media_type`.
- `season`: заголовок `Cache-Control: max-age=3600`, дальше смотри остановку 5.
- **Урок про роутер (баг, который у нас был):** маршруты `/titles/:type/:id` и `/titles/tv/:id/seasons/:n` выглядели безобидно. Но роутер Vapor всегда выбирает фиксированный сегмент (`tv`) вместо параметра (`:type`) и назад не возвращается. Поэтому `/titles/tv/1668` уходил во вторую ветку, не находил там обработчика и отвечал 404, а фильмы работали. Исправление: в обоих маршрутах `:type`. Тест `seriesRoutes` ловит это.

**Руками:** добавь в `TitleCard` поле `originalLanguage` (у TMDB `original_language`), отдай его и выведи на карточке.

## 4. Вход: Bcrypt, токены, Keychain

**Открой:** `Models/User.swift`, `AuthController.swift`, `iOS/Lumikos/Auth/`.

- Пароль хранится только как хэш **Bcrypt** (`req.password.async.hash`). Bcrypt медленный специально, так перебор становится дорогим.
- Токен: 32 случайных байта. Приложению отдаём сам токен, в базе храним **SHA-256** от него. Украденная база не даёт войти.
- Одинаковый ответ на «нет такого пользователя» и «неверный пароль», чтобы нельзя было проверять почты.
- `TokenAuthenticator` + `User.guardMiddleware()`: всё в `protected` требует `Authorization: Bearer`. Поэтому `/titles/tv/1668`, открытый в браузере, отвечает 401: у браузера нет токена.
- В приложении: токен в **Keychain** (`TokenStore`), поля помечены `textContentType`, поэтому iOS предлагает надёжный пароль.

**Чего нет (и это задания):** подтверждение почты, сброс пароля, лимит попыток, Sign in with Apple (нужен платный аккаунт).

**Руками:** сделай так, чтобы `POST /auth/logout` без токена отвечал 401, и допиши тест в `Backend/Tests`.

## 5. Сеть в два файла

**Открой:** `Network/Endpoint.swift`, `Network/APIClient.swift`, `UI/Components.swift` (`PosterImage`).

- `Endpoint`: enum со всеми запросами. Новый запрос = новый case.
- `APIClient.send`: `URLRequest` → `URLSession.data(for:)` (async) → `JSONDecoder`. Около 60 строк, сторонних пакетов нет.
- **Кэш бесплатно:** `URLCache` хранит ответы с `Cache-Control` и картинки `AsyncImage`. Второй раз сезон открывается без запроса.
- На 401 `onUnauthorized` отправляет на экран входа.
- **Было:** Alamofire, свой кэш картинок (Kingfisher/SDWebImage). **Стало:** всё есть в Foundation и SwiftUI.

**Руками:** добавь `case me` для `GET /me` и покажи почту в меню профиля.

## 6. MVVM + `@Observable`, координаторы, поиск

**Открой:** `App/AppCoordinator.swift`, `Feed/FeedCoordinator.swift`, `Feed/FeedViewModel.swift`, `Feed/FeedView.swift`, `Search/SearchViewModel.swift`.

- `@Observable` (Observation, iOS 17+): SwiftUI сам следит за свойствами, которые прочитал `body`. Не нужны `@Published` и `ObservableObject`.
- ViewModel ничего не знает о навигации, у неё только замыкания `onOpenDetails`. Координатор их подписывает и делает `pushViewController`.
- Экран SwiftUI живёт в `UIHostingController`, навигация на привычных `UITabBarController` и `UINavigationController`. Детали общие для обеих вкладок: `Coordinator.showDetails`.
- `SwipeCard`: `DragGesture` + `offset` + `rotationEffect`, анимация с `completion`.
- **Поиск:** `.searchable` во вкладке «Мой список». Debounce без Combine: `.task(id: query)` перезапускается на каждую букву и отменяет прошлую задачу, а `Task.sleep(400 ms)` внутри ждёт, пока ты перестанешь печатать.

**Руками:** добавь кнопку «Отменить» (вернуть последнюю пропущенную карточку) в `FeedViewModel`.

## 7. actor, Combine, SwiftData

**Открой:** `Feed/FeedLoader.swift`, `Network/NetworkMonitor.swift`, `List/CachedItem.swift`, `List/ListViewModel.swift`.

- **actor** `FeedLoader`: методы выполняются по одному, поэтому быстрые свайпы не запустят две загрузки страницы. Обрати внимание на реентерабельность: пока идёт `await`, может войти второй вызов, и его ловит флаг `isLoading`.
- **Combine** `NetworkMonitor`: `CurrentValueSubject` + `removeDuplicates`. `ListViewModel.observeNetwork` подписывается через `sink`, держит `AnyCancellable` и переходит на главный поток через `receive(on:)`.
- **SwiftData** `CachedItem`: `@Model`-класс, `ModelContainer`, `context.fetch`. Сервер главный, локально только копия для офлайна, поэтому никакой синхронизации.
- **Swift 6 и акторы в тестах:** `ListViewModel.arrange` помечен `nonisolated`. Класс целиком `@MainActor`, а Swift Testing запускает тесты не на главном акторе, без `nonisolated` тест не компилировался.

**Руками:** выключи Wi-Fi на Mac (симулятор берёт сеть у него) и посмотри плашку и список. Потом добавь в `NetworkMonitor` `debounce(for: .seconds(1), scheduler: RunLoop.main)`, чтобы плашка не мигала.

## 8. Тесты и Maestro

**Открой:** `iOS/LumikosTests/LumikosTests.swift`, `Backend/Tests/AppTests/AppTests.swift`, `.maestro/smoke.yaml`.

- **Swift Testing:** `@Test`, `#expect`, `#require`, параметризованные тесты (`arguments:`). Сервер тестируется целиком на SQLite в памяти, TMDB не вызывается.
- **Maestro:** YAML-сценарий жмёт кнопки по `accessibilityIdentifier` из `AXID.swift`. Регистрирует случайного пользователя, лайкает карточку, проверяет список.

**Руками:** напиши тест `FeedLoader`: второй одновременный вызов `nextPage()` возвращает пустой массив.

## 9. Docker, CI и деплой на Render

**Открой:** `Backend/Dockerfile`, `Backend/.dockerignore`, `.github/workflows/ci.yml`.

- **Зачем Docker:** Render запускает не исходники, а готовый образ: маленький Linux, внутри которого лежит собранный сервер. Образ одинаково работает на твоём Mac, в CI и на Render.
- **Dockerfile в два этапа:**
  1. `FROM swift:6.x AS build`: полный Swift. Сначала копируются только `Package.*` и выполняется `swift package resolve`: Docker кэширует этот слой, и при правке кода пакеты не качаются заново. Потом `swift build -c release --static-swift-stdlib` вшивает рантайм Swift в бинарник.
  2. `FROM ubuntu`: чистая Ubuntu, куда копируется только бинарник `App`. Образ весит около 100 МБ вместо 1+ ГБ. Сервер запускается не от root, `AUTO_MIGRATE=true` создаёт таблицы при старте.
- `.dockerignore`: в образ не попадают `.build/`, `db.sqlite` и `.env` с токеном.
- **Как образ доезжает до Render (джоба `deploy` в `ci.yml`):** только на `main` и только после зелёных тестов сервера.
  1. `docker/build-push-action` собирает образ из папки `Backend`, кэш слоёв хранится в GitHub Actions (`type=gha`).
  2. Образ уходит в GitHub Container Registry с двумя тегами: `ghcr.io/disavle/lumikos-backend:latest` и `:<sha коммита>`. Логин через встроенный `GITHUB_TOKEN`, отдельный секрет не нужен. Пакет должен быть Public, иначе Render его не скачает.
  3. `curl` дёргает `RENDER_DEPLOY_HOOK` (секрет репозитория) с `imgURL=...:<sha>`. Render скачивает ровно этот образ и перезапускает сервис, в Logs видно «Deploy live».
  4. Переменные окружения (`DATABASE_URL`, `TMDB_TOKEN`, `PORT`) Render передаёт в контейнер сам, в образе их нет.
- **Сборка на Mac:** нужен Docker Desktop или OrbStack.
  ```bash
  docker build -t lumikos-backend Backend
  docker run --rm -p 8080:8080 -e TMDB_TOKEN=eyJ... lumikos-backend
  ```
  Без `DATABASE_URL` сервер в контейнере использует SQLite, данные пропадут после остановки.

**Руками:** собери образ локально, открой `http://localhost:8080/health`, потом посмотри размер: `docker images lumikos-backend`.

---

## Что убрано и что дальше

- **Фичетогглы убраны** (раньше были `/config` и таблица `flags`). Если понадобятся: таблица `flags(key, enabled)`, публичный `GET /config` и кэш ответа на клиенте. В старой базе Neon таблица `flags` осталась, её можно удалить запросом `DROP TABLE flags;`.
- Sign in with Apple (`AuthenticationServices` + `vapor/jwt`), когда будет аккаунт разработчика.
- Сброс пароля по почте, лимит попыток входа.
- Переписать `APIClient` через Apple `swift-openapi-generator` и сравнить.
