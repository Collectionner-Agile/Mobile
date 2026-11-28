# Collectionner — Flutter mobile app (Android / iOS)

Native Flutter client for the Collectioneer Spring backend. No WebView: every screen is
built with Flutter widgets. The Astro web app ([Collectionner-Agile/Frontend](https://github.com/Collectionner-Agile/Frontend)) stays as the reference implementation; the API is [Collectionner-Agile/Backend](https://github.com/Collectionner-Agile/Backend).

## Stack

| Concern | Choice |
| --- | --- |
| Flutter / Dart | 3.47.8 stable / 3.13.7, strict analysis (`analysis_options.yaml`) |
| State | Riverpod 3 (`Notifier`, `FutureProvider`), no code generation |
| Navigation | go_router 18: five-tab `StatefulShellRoute` (Inicio, Catálogo, Escanear, Subastas, Comunidades) on a floating pill bar whose active tab stretches into an ink capsule, cross-faded tabs, profile from the avatar, protected routes, deep links `collectionner://app/...` |
| Design | "Slab" tokens: cool grey ground, black ink for structure and actions, lacquer red only for what is live; Fraunces for titles and prices, Archivo for UI; Material icons; pieces cased like graded collectibles (`lib/core/widgets/slab.dart`); motion kit in `lib/core/widgets/motion.dart` and `kit.dart` |
| HTTP | Dio wrapped in `ApiClient`; every failure becomes a typed `ApiException` (RFC 9457 aware) |
| Session | JWT in Android Keystore / iOS Keychain (`flutter_secure_storage`), excluded from backups |
| Images | In-app live camera (`camera`, CameraX) for scanning, `image_picker` for the gallery, `image_cropper`, re-encode on an isolate (EXIF stripped) |
| Sharing | `share_plus` for piece cards rendered to PNG |
| i18n | `gen-l10n`, Spanish (template) + English, device language by default, persisted override |

```
lib/
  app/        config, theme (tokens + Material 3), router + shell, preferences, providers
  core/       network (client, repositories), storage, media pipeline, utils, shared widgets
  features/   auth · catalog · auctions · communities · profile · recognition · home
              each with domain/ (models), application/ (state), presentation/ (screens)
  l10n/       app_es.arb, app_en.arb (+ generated)
```

## Screens beyond the web

Launch scene and farewell exit (`features/launch`), photo viewer, live camera, followed auctions, my bids,
auction calendar and results, notices, my collection, categories and category pages, help centre and
guides, appearance, about, trending, achievements, collector pages, compare, scan history, share piece and
an animated success screen. Notices, achievements, followed auctions and scan history are derived from data
the app already loads or kept on the device; none needs a new endpoint.

## Web → mobile migration matrix

| Web route | Flutter screen | Backend (`/api/v1`) | Status |
| --- | --- | --- | --- |
| `/` | `HomeScreen` | collectibles, auctions, communities | Migrated |
| `/marketplace` | `CatalogScreen` (search, category chips, sort) | `GET collectibles` | Migrated |
| `/marketplace/:id` | `CollectibleDetailScreen` (gallery, reviews, comments, owner actions) | collectibles/{id}, reviews, comments, media | Migrated |
| `/collectibles/new` | `PublishCollectibleScreen` (+ photos) | `POST collectibles`, `POST media/upload` | Migrated |
| `/auctions`, `/auctions/:id` | `AuctionsScreen`, `AuctionDetailScreen` (countdown, bid sheet, history) | auctions, `POST auctions/bids` | Migrated |
| "Convertir a subasta" | `showCreateAuctionSheet` | `POST auctions`, `DELETE auctions/{id}` | Migrated |
| `/communities`, `/communities/:id`, `/communities/new` | list + search, detail (feed, filters, join/leave), create | communities, feed, join | Migrated |
| `/posts/new`, post view | `CreatePostScreen`, `PostDetailScreen` (comments, delete) | posts, posts/{id}/comments | Migrated |
| `/auth/login`, `/register`, `/forgot-password`, `/reset-password` | `auth_screens.dart` | auth/* | Migrated |
| `/profile`, `/account/settings`, `/auth/change-password` | `ProfileScreen`, `EditProfileScreen`, `SettingsScreen`, `ChangePasswordScreen` | auth/me, users/me, change-password, delete-account | Migrated |
| `/ai/condition` (demo) | `ScanScreen` + `ScanResultScreen` | **new** `recognition/analyze`, `recognition/status` | Replaced by real Gemini recognition |
| Sale checkout (`/checkout/:saleId`), `/exchanges` | — | not in the Spring backend (web uses a local fake API) | **Not migrated** (see below) |
| OAuth Google/GitHub buttons | — | disabled server-side, no credentials | Not shown |
| Cookie banner, legal drafts, AI chat demo | — | web-only / demo | Not applicable |

## Recognition training data (phase 1)

The app collects the signals needed to train recognition later. The backend must implement the
parts marked **new**; until it does, feedback calls fail quietly (the user sees a short "couldn't
send" toast after an explicit answer, implicit signals are dropped).

| What | Request | Backend contract |
| --- | --- | --- |
| Consent | `POST /api/v1/recognition/analyze`, extra multipart field `training_consent` = `"true"`/`"false"` | **new**: keep the photo (and later feedback) for training only when `"true"`; otherwise discard it after answering, as today. Off by default; toggled in the scanner and in Settings → Reconocimiento (`pref.recognitionTrainingConsent`). |
| Feedback | `POST /api/v1/recognition/{analysis_id}/feedback`, JSON body below | **new**: store per analysis, last answer wins; `2xx` with any or no body. |
| Listing ↔ scan | `POST /api/v1/collectibles`, extra field `recognitionAnalysisId` | **new**: persist the link; the published piece (name, category, photos) is the user's label for that analysis. |

Feedback body (`RecognitionFeedback.toJson`, empty fields omitted):

```json
{
  "verdict": "correct | chose_match | incorrect",
  "collectible_id": 4,
  "corrected_name": "Lego Millennium Falcon 75192",
  "corrected_category": "Lego & Sets",
  "implicit": false
}
```

- `correct`: the user tapped "Sí, es correcto"; `collectible_id` is the catalogue match or the
  alternative they had selected.
- `chose_match`: the user picked an alternative. `implicit: true` when it was inferred from
  continuing to that piece rather than answered.
- `incorrect`: the user tapped "No, corregir"; the correction fields are optional.

## Run

```bash
# 1. Backend with seeded data (Collectionner-Agile/Backend checkout)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
# 2. Phone over USB, backend reachable as 127.0.0.1:8080 on the device
adb reverse tcp:8080 tcp:8080
flutter run -d <device-id>
# Any HTTPS backend
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Cleartext HTTP is allowed only for `127.0.0.1`/`localhost` (`network_security_config.xml`);
everything else must be HTTPS. The app holds no AI key: recognition runs on the backend.

## Quality gates

```bash
dart format --line-length 120 lib test integration_test
flutter analyze
flutter test                      # unit + widget + responsive matrix
flutter test integration_test -d <device-id>   # real backend, see file header
flutter build apk --release
flutter build appbundle --release
```

The responsive matrix renders every main route at 320×568, 412×915 (S26 Ultra logical
size) and 915×412, with text scale 1.0/1.5/2.0, light/dark and es/en; any RenderFlex
overflow fails the test.

## Release signing

Create `android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. Without it, release builds are signed with the debug key: fine for
sideloading, rejected by Google Play.

## Known gaps

- **Sales (HU05)** run against the backend's `/api/v1/sales`: buy a listed piece, list your own,
  confirm delivery or receipt, call it off before anyone confirms; "Mis compras y ventas" in the
  profile. No payment goes through the app.
- **Exchanges** still only exist in the web's local fake API; the Spring backend has no endpoints
  for them yet, so they were not migrated rather than faked.
- **AI recognition** needs `GEMINI_API_KEY` on the backend; without it the server reports
  `enabled: false` and the app says so instead of pretending.
- **iOS** project is configured (permissions, URL scheme, icons, splash) but was not built:
  that requires macOS/Xcode.
