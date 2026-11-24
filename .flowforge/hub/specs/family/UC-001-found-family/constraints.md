# Constraints — UC-001-found-family

## Security

- The password is stored only as a salted, slow one-way hash (bcrypt or stronger). It is never returned, logged or included in error details.
- The session token is an opaque random value of at least 128 bits. The server stores only a hash of it, so a database read does not reveal usable tokens.
- Founding is serialized by the family-wide lock: one PostgreSQL transaction-scoped advisory lock, shared with the last-active-parent guard of UC-014. The check that no family member exists and the creation of the first parent happen under that lock in one transaction, so two simultaneous setups cannot both succeed.

## Business Rules

- A family exists once any family member exists, whatever its role or status. There is no separate family record.
- Username uniqueness is case-insensitive and is enforced by the database through a username-reservation table keyed by the lower-case username. A family member and a pending registration each hold one reservation, so one unique key covers both. Each reservation names its holder: a family member id or a registration id, exactly one of them set. The reservation table is a technical means of enforcing this rule, not a domain entity.
- Family members carry created_at and updated_at timestamps. Sessions carry a created_at timestamp. No other attribution or device data is stored.
