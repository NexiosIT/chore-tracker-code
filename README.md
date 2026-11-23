# Chore Tracker — code

Code for Chore Tracker. Specs live in the product hub, [NexiosIT/chore-tracker](https://github.com/NexiosIT/chore-tracker); code here is generated from them with `/ie/generate`.

| Folder | Service | Stack |
|--------|---------|-------|
| `backend/` | `chore-tracker-api` | Kotlin, Spring Boot 4.0, PostgreSQL (JPA, Flyway), Java 21 |
| `app/` | `chore-tracker-app` | Flutter (Android 10+, `minSdk` 29) |

## Backend

```bash
cd backend
./gradlew build
```

Tests need a PostgreSQL database; set `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` and `SPRING_DATASOURCE_PASSWORD`.
