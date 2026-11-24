# Constraints — UC-012-reset-member-password

## Security

- The new password is stored only as a salted, slow one-way hash and is never logged or returned.
- The password replacement, the ending of the target's sessions, the writing of their session end records and the clearing of the lockout happen in one transaction. The member's row is updated before the sessions are removed. That takes the row lock a login (UC-003) reads under, so a login with the old password either finishes first and its session is removed, or waits and fails with the new password in place.

## Business Rules

- A parent cannot reset their own password here. They use change password (UC-011), which asks for the current one.
- The lockout cleared is the one keyed by the target member's username in lower case.
- A deactivated member's password can be reset. The member stays deactivated.
