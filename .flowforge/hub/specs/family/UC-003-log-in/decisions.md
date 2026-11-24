# Decision Table — UC-003-log-in

## Login outcome

Checked top to bottom; the first matching row decides. "Count" is the failed-attempt count of the submitted username, in lower case.

| Username or password missing? | Username locked now? | Member with this username (any case)? | Pending registration with it? | Password matches what? | Member active? | Outcome | Count | Scenario |
|---|---|---|---|---|---|---|---|---|
| Yes | * | * | * | * | * | 400 VALIDATION_FAILED | unchanged | Missing username or password is invalid |
| No | Yes | * | * | * | * | 429 RATE_LIMIT_LOGIN_LOCKED with retryAt | unchanged | A locked username is rejected even with the right password |
| No | No | Yes | * | Member's password | Yes | 201 session started | reset to 0 | Successful login with the username in another case |
| No | No | Yes | * | Member's password | No | 403 AUTHORIZATION_ACCOUNT_DEACTIVATED | unchanged | Deactivated member with a matching password is denied |
| No | No | Yes | * | Not the member's password | * | 401 AUTHENTICATION_FAILED, or 429 if this is the 5th failure | +1 | Wrong password fails with the generic message |
| No | No | No | Yes | Pending registration's password | * | 403 AUTHORIZATION_REGISTRATION_PENDING | unchanged | Pending registration with a matching password is denied |
| No | No | No | Yes | Not the pending registration's password | * | 401 AUTHENTICATION_FAILED, or 429 if this is the 5th failure | +1 | Wrong password fails with the generic message |
| No | No | No | No | A rejected registration's password | * | 403 AUTHORIZATION_REGISTRATION_REJECTED | unchanged | Rejected registration with a matching password is denied |
| No | No | No | No | Nothing | * | 401 AUTHENTICATION_FAILED, or 429 if this is the 5th failure | +1 | Unknown username fails with the same generic message |

Notes:

- A member row wins over any rejected registration with the same username, because a rejected registration frees its username for reuse.
- A pending registration's username cannot also belong to a member, because pending registrations reserve their username.
- The 5th consecutive failure locks the username for 15 minutes from that moment and already answers 429 (scenario "The fifth consecutive failure is rejected with a lockout"). When the lockout ends the count restarts at 0 (scenario "Edge case — the lockout ends after 15 minutes").
