# Constraints — UC-006-register-kid

## Security

- The password is stored only as a salted, slow one-way hash (bcrypt or stronger). It is never returned, logged or included in error details.
- The same hash is later copied to the kid's account at approval (UC-008), so the kid never retypes it.

## Business Rules

- Username uniqueness spans family members and pending registrations, ignoring case. It is enforced by the username-reservation table keyed by the lower-case username, so two simultaneous registrations cannot both take one username. Each reservation names its holder: a family member id or a registration id, exactly one of them set. A pending registration holds a reservation; approval re-points it to the new member (UC-008) and rejection deletes it (UC-009), so a kept rejected registration holds no reservation.
- The registration stores its requested time. Its decision fields (deciding parent, decision time, created member) stay empty while it is pending.
- Checks run in this order: family exists, then input rules, then username uniqueness. A request that breaks input rules gets only the 400 answer.
