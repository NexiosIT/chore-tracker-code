# Constraints — UC-009-reject-registration

## Business Rules

- The registration is locked while it is decided, so a reject and an approve cannot both succeed.
- Rejection marks the registration rejected, deletes its username reservation (the kept registration holds none), and records the deciding parent and the decision time, in one transaction. The registration itself is kept.
