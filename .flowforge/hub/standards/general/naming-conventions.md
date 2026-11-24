---
id: STD-003
name: "Naming Conventions"
version: "1.0.0"
category: general
status: active
last_reviewed: "2026-04-06"
---

# Naming Conventions

> All code artifacts MUST follow consistent naming conventions for files, directories, variables, functions, classes, API paths, database objects, and events.

## Motivation

Inconsistent naming creates cognitive overhead — developers waste time guessing whether it's `userId`, `user_id`, or `UserID`. Generated code that follows unpredictable naming requires more manual review. Consistent conventions make the codebase navigable, the generated output predictable, and refactoring tools reliable.

## Rules

1. **File names** MUST use kebab-case: `user-profile.ts`, `order-service.py`, `product-list.vue`.

2. **Directory names** MUST use kebab-case: `user-management/`, `api-gateway/`, `order-processing/`.

3. **Variables and function parameters** MUST use camelCase: `userId`, `orderTotal`, `isActive`.

4. **Functions and methods** MUST use camelCase and start with a verb: `createUser()`, `validateOrder()`, `fetchProducts()`, `isEligible()`.

5. **Classes, types, and interfaces** MUST use PascalCase: `UserProfile`, `OrderService`, `ProductRepository`, `CreateUserRequest`.

6. **Constants** MUST use SCREAMING_SNAKE_CASE: `MAX_RETRY_COUNT`, `DEFAULT_PAGE_SIZE`, `API_BASE_URL`.

7. **Boolean variables and properties** MUST use a prefix from: `is`, `has`, `can`, `should`, `was`, `will`: `isActive`, `hasPermission`, `canEdit`, `shouldRetry`.

8. **API URL paths** MUST use kebab-case and plural nouns for resource collections:
   - `/api/v1/user-profiles` (collection)
   - `/api/v1/user-profiles/{id}` (single resource)
   - `/api/v1/order-items/{id}/reviews` (nested resource)

9. **Database table/collection names** MUST use snake_case and plural: `user_profiles`, `order_items`, `payment_transactions`. Column names MUST use snake_case: `created_at`, `user_id`, `is_active`.

10. **Event names** MUST use past-tense dot notation: `order.created`, `user.updated`, `payment.failed`, `inventory.reserved`.

11. **Environment variables** MUST use SCREAMING_SNAKE_CASE with a project prefix: `APP_DATABASE_URL`, `APP_JWT_SECRET`, `APP_REDIS_HOST`.

12. **Enum values** MUST follow the idiomatic convention of the language:
   - **Java / Kotlin:** SCREAMING_SNAKE_CASE — `OrderStatus.PENDING_APPROVAL`, `Role.ADMIN`.
   - **TypeScript / JavaScript:** PascalCase — `OrderStatus.PendingApproval`, `Role.Admin`. SCREAMING_SNAKE_CASE is also acceptable when the enum represents fixed constants (e.g., `HttpMethod.GET`).
   - **Python:** SCREAMING_SNAKE_CASE — `OrderStatus.PENDING_APPROVAL`, `Role.ADMIN`.
   - **Go:** PascalCase with type prefix — `OrderStatusPendingApproval`, `RoleAdmin`.
   - **C# / .NET:** PascalCase — `OrderStatus.PendingApproval`, `Role.Admin`.
   - Do NOT mix conventions within the same codebase. Pick one style per language and apply consistently.

## Examples

### Compliant: Consistent naming across layers

```
Directory:    src/user-management/
File:         user-profile-service.ts
Class:        UserProfileService
Method:       updateProfile(userId, profileData)
Variable:     const isVerified = user.hasVerifiedEmail
Constant:     const MAX_LOGIN_ATTEMPTS = 5
API path:     PUT /api/v1/user-profiles/{id}
DB table:     user_profiles
DB column:    updated_at
Event:        user.profile.updated
Env var:      APP_AUTH_TOKEN_EXPIRY
Enum (Java):  OrderStatus.PENDING_APPROVAL
Enum (TS):    OrderStatus.PendingApproval
```

### Non-Compliant: Mixed conventions

```
Directory:    src/UserManagement/          // PascalCase directory
File:         userProfileService.ts        // camelCase file
Class:        user_profile_service         // snake_case class
Method:       Update_Profile()             // Mixed case method
Variable:     const verified = ...         // Missing boolean prefix
Constant:     const maxRetryCount = 5      // camelCase constant
API path:     PUT /api/v1/UserProfiles     // PascalCase URL
DB table:     UserProfile                  // PascalCase, singular
Event:        updateUser                   // camelCase, present tense
Env var:      databaseUrl                  // camelCase, no prefix
Enum (Java):  OrderStatus.pendingApproval  // camelCase in Java
Enum (TS):    OrderStatus.PENDING_APPROVAL // SCREAMING_SNAKE in TS (unless constant-like)
```

### Edge cases

- **Acronyms in PascalCase:** Treat as a word — `HttpClient`, `JsonParser`, `ApiResponse` (not `HTTPClient`, `JSONParser`).
- **Acronyms in camelCase:** Lowercase the acronym — `httpClient`, `jsonData`, `apiUrl`.
- **Test files:** Mirror the source file name with a `.test` or `.spec` suffix: `user-profile-service.test.ts`.
- **Index/barrel files:** Use `index.ts` or `index.js` — the directory name provides context.

## Applicability

- **Service types:** all (backend, frontend, gateway)
- **Domains:** all
- **Exceptions:** Third-party library conventions may override in integration code (e.g., if a database ORM requires a specific naming pattern). Document the deviation in the service's README.

## References

- STD-004: Component Structure (component file naming follows these conventions)
- STD-002: Error Handling Strategy (error codes follow SCREAMING_SNAKE_CASE per Rule 6)
