# Экскурсия по Lumikos

8 остановок по 20–30 минут. В каждой: что открыть, на что смотреть, чем это отличается от UIKit, и одно маленькое изменение руками. Код читай в Xcode, сервер в любом редакторе.

Карта проекта:

```
Backend/Sources/App/      сервер на Vapor (11 файлов)
iOS/Lumikos/App/          запуск, координаторы, зависимости
iOS/Lumikos/Network/      сеть: APIClient, Endpoint, модели, NetworkMonitor
iOS/Lumikos/Auth/         вход и регистрация, Keychain
iOS/Lumikos/Feed/         вкладка «Для тебя»: свайпы
iOS/Lumikos/List/         вкладка «Мой список» и SwiftData-копия
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

## 1. Запуск: mise, Tuist, сервер

**Открой:** `mise.toml`, `iOS/Project.swift`, `Backend/.env.example`.

- **mise** фиксирует версии инструментов (`[tools]`) и хранит короткие команды (`[tasks]`). Как `.nvmrc` + `Makefile` в одном файле.
- **Tuist** генерирует `.xcodeproj` из Swift-кода. Проектный файл не лежит в git, значит конфликтов в `project.pbxproj` не бывает. Один таргет приложения и один для тестов.
- **Было в UIKit:** проект руками в Xcode, `Info.plist` файлом. **Стало:** `infoPlist: .extendingDefault(with:)` прямо в `Project.swift`.

**Руками:** запусти `mise run api` и `mise run generate`, открой `http://localhost:8080/health` в браузере, потом поменяй `CFBundleDisplayName` в `Project.swift` и сгенерируй снова.

## 2. Vapor: роуты, модели, миграции

**Открой:** `routes.swift`, `Models/ListItem.swift`, `Controllers/ListController.swift`.

- Роут = путь + async-функция. Возвращаешь `Content`-структуру, Vapor сам делает JSON.
- Fluent-модель: класс с `@ID`, `@Field`, `@Parent`. Миграция рядом: создаёт таблицу. Локально база SQLite-файл, на Render Postgres, код один.

**Руками:** добавь в `ListItem` поле `note` (заметка к фильму): `@OptionalField`, колонка в `CreateListItem`, поле в DTO. Удали `Backend/db.sqlite`, перезапусти сервер и проверь `GET /list`.

## 3. BFF: сервер как прослойка над TMDB

**Открой:** `TMDB/TMDB.swift`, `Controllers/TitlesController.swift`.

- BFF (backend for frontend): приложение не знает про TMDB. Сервер прячет токен, выбирает язык по `Accept-Language` и превращает большие ответы TMDB в маленькие DTO (`TitleCard`, `TitleDetails`).
- `feed`: `withTaskGroup` запрашивает рекомендации для трёх тайтлов **параллельно**, это structured concurrency на сервере.
- `season`: заголовок `Cache-Control: max-age=3600`, дальше смотри остановку 5.

**Руками:** добавь в `TitleCard` поле `originalLanguage` (у TMDB `original_language`), отдай его и выведи на карточке.

## 4. Вход: Bcrypt, токены, Keychain

**Открой:** `Models/User.swift`, `AuthController.swift`, `iOS/Lumikos/Auth/`.

- Пароль хранится только как хэш **Bcrypt** (`req.password.async.hash`). Bcrypt медленный специально, так перебор становится дорогим.
- Токен: 32 случайных байта. Приложению отдаём сам токен, в базе храним **SHA-256** от него. Украденная база не даёт войти.
- Одинаковый ответ на «нет такого пользователя» и «неверный пароль», чтобы нельзя было проверять почты.
- `TokenAuthenticator` + `User.guardMiddleware()`: всё в `protected` требует `Authorization: Bearer`.
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

## 6. MVVM + `@Observable` и координаторы

**Открой:** `App/AppCoordinator.swift`, `Feed/FeedCoordinator.swift`, `Feed/FeedViewModel.swift`, `Feed/FeedView.swift`.

- `@Observable` (Observation, iOS 17+): SwiftUI сам следит за свойствами, которые прочитал `body`. Не нужны `@Published` и `ObservableObject`.
- ViewModel ничего не знает о навигации, у неё только замыкания `onOpenDetails`. Координатор их подписывает и делает `pushViewController`.
- Экран SwiftUI живёт в `UIHostingController`, навигация на привычных `UITabBarController` и `UINavigationController`. Детали общие для обеих вкладок: `Coordinator.showDetails`.
- `SwipeCard`: `DragGesture` + `offset` + `rotationEffect`, анимация с `completion`.

**Руками:** добавь кнопку «Отменить» (вернуть последнюю пропущенную карточку) в `FeedViewModel`.

## 7. actor, Combine, SwiftData

**Открой:** `Feed/FeedLoader.swift`, `Network/NetworkMonitor.swift`, `List/CachedItem.swift`, `List/ListViewModel.swift`.

- **actor** `FeedLoader`: методы выполняются по одному, поэтому быстрые свайпы не запустят две загрузки страницы. Обрати внимание на реентерабельность: пока идёт `await`, может войти второй вызов, и его ловит флаг `isLoading`.
- **Combine** `NetworkMonitor`: `CurrentValueSubject` + `removeDuplicates`. `ListViewModel.observeNetwork` подписывается через `sink`, держит `AnyCancellable` и переходит на главный поток через `receive(on:)`.
- **SwiftData** `CachedItem`: `@Model`-класс, `ModelContainer`, `context.fetch`. Сервер главный, локально только копия для офлайна, поэтому никакой синхронизации.

**Руками:** выключи Wi-Fi на Mac (симулятор берёт сеть у него) и посмотри плашку и список. Потом добавь в `NetworkMonitor` `debounce(for: .seconds(1), scheduler: RunLoop.main)`, чтобы плашка не мигала.

## 8. Тесты, Maestro, деплой

**Открой:** `iOS/LumikosTests/LumikosTests.swift`, `Backend/Tests/AppTests/AppTests.swift`, `.maestro/smoke.yaml`, `.github/workflows/ci.yml`.

- **Swift Testing:** `@Test`, `#expect`, `#require`, параметризованные тесты (`arguments:`). Сервер тестируется целиком на SQLite в памяти.
- **Maestro:** YAML-сценарий жмёт кнопки по `accessibilityIdentifier` из `AXID.swift`. Регистрирует случайного пользователя, лайкает карточку, проверяет список.
- **CI:** три джобы: тесты iOS, тесты сервера, деплой (образ в ghcr.io → Render Deploy Hook).

**Руками:** напиши тест `FeedLoader`: второй одновременный вызов `nextPage()` возвращает пустой массив.

---

## Что дальше, если захочется

- Sign in with Apple (`AuthenticationServices` + `vapor/jwt`), когда будет аккаунт разработчика.
- Сброс пароля по почте, лимит попыток входа.
- Переписать `APIClient` через Apple `swift-openapi-generator` и сравнить.
