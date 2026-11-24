# Constraints — UC-008-approve-registration

## Business Rules

- The registration is locked while it is decided, so two parents cannot both approve it, or approve and reject it at the same time.
- Approval creates the kid, re-points the username reservation from the registration to the new member, and records the deciding parent, the decision time and the created member id, all in one transaction.
- The kid's password hash is copied from the registration; the kid never retypes the password.
