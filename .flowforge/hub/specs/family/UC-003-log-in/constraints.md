# Constraints — UC-003-log-in

## Security

- Passwords are compared against the stored salted hash only. A password is never logged or returned.
- An unknown username and a wrong password take comparable time to answer, so the response time does not reveal which usernames exist.
- The session token is an opaque random value of at least 128 bits. The server stores only a hash of it.
- A lockout is a `rate_limit` error in STD-002 (Error Handling Strategy, Rule 1) and answers 429. Per STD-002 Rule 11 the 429 carries a `Retry-After` header with the whole seconds until `retryAt`.

## Business Rules

- The failed-attempt count is keyed by the submitted username in lower case, whether or not that username exists.
- Only an unknown username or a wrong password counts as a failure. A missing field, a lockout refusal, or a matching password for a pending, rejected or deactivated account does not change the count.
- When the fifth consecutive failure happens, the username is locked for 15 minutes from that moment, and that fifth attempt already gets the lockout answer. When the lockout ends, the count restarts at zero.
- A member can hold several sessions, one per device. Sessions have no idle timeout.
- When several rejected registrations share the username, any of them with a matching password gives the rejected answer.
- A session stores its member, the hash of its token and its created_at time. When a session ends, its row is removed and a session end record is written (see UC-004, UC-011, UC-012 and UC-014).
- A login starts its session in one transaction. That transaction first reads the member's row with a share lock (PostgreSQL `SELECT … FOR SHARE`), checks status and password hash under that lock, and only then inserts the session. Every use case that ends a member's sessions (UC-011, UC-012, UC-014) first updates that member's row, which takes the row lock, and only then removes the sessions. A login racing one of them therefore either commits first, so its new session is removed with the others, or waits and then sees the new status or password.
