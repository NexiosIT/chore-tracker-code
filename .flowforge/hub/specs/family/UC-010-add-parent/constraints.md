# Constraints — UC-010-add-parent

## Security

- The initial password is stored only as a salted, slow one-way hash (bcrypt or stronger). It is never returned, logged or included in error details.

## Business Rules

- Username uniqueness is enforced by the username-reservation table keyed by the lower-case username, shared with pending registrations, so a simultaneous registration cannot take the same username.
