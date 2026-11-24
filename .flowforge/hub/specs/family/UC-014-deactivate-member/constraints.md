# Constraints — UC-014-deactivate-member

## Business Rules

- Deactivation deletes nothing. Later features decide what a deactivated member's chores, points and redemptions mean.
- The check that at least one active parent remains and the status change happen under the family-wide lock: the PostgreSQL transaction-scoped advisory lock shared with founding (UC-001). Two parents therefore cannot deactivate each other at the same moment.
- The status change, the removal of the member's sessions and the writing of their session end records happen in one transaction.
- Within that transaction the member's row is updated before their sessions are removed. The update takes the row lock that a login (UC-003) reads under, so no login can add a session for this member after the removal. A login that started first either finishes before the update, and its session is removed, or waits and is refused as deactivated.
