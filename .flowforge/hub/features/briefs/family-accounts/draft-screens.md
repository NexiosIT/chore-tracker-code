---
source: sandbox-hub
source_remote: ''
source_commit: ''
sandbox_slug: family-accounts
synced_at: '2026-11-23T14:35:06.842Z'
cli_version: 1.7.0
body_sha256: ebececea33c233c7443bff4dfa980237bb2a3414ab1c521c89a480159232f79a
---

# Draft screens — Family accounts and kid registration

Written by `/ie/create-feature-mockup` on 2026-11-23 from the mockup in
`src/features/family-accounts/`. Advisory input for shaping, not a spec.

**How the screens are realized.** The chore-tracker design system declares no vendor library and
no in-house module for any component these screens use. Every one is a token-rendered primitive
from `_base/inventory.yml`: `container`, `card`, `heading`, `text`, `badge`, `button`, `form`,
`form-field`, `inline`, `banner`, `list`, `table` and `modal`. The mockup composes them as markup
styled from the hub's semantic tokens. `toast` is not used: every confirmation here is a `banner`
that stays on screen.

**Not build-checked.** npm was unavailable on the authoring machine, so the token compile, the
inventory check and the dev server never ran. The screens below describe what was written, not
what was seen rendering.

Navigation between screens is described per screen below. In the mockup, links between screens
are placeholders; the shell's screen selector is how a reviewer moves between them.

---

## 1. Set up the family (Setup_Screen)

**For:** the first person on a fresh install creates the family and becomes its first parent
(Requirement 1).

**In:** the app opens here while no family exists. It is never offered after that.
**Out:** a successful setup logs the new parent in and opens the parent home (screen 5).

**Fields:** Username, Display name, Password (each with its rule as a hint), and a checkbox
"I am a parent setting up this family".
**Actions:** Create family.

**States:**
- *Empty*: the form with hints.
- *Refused*: an error `banner` at the top lists **every** broken rule (decision 22), and each field
  carries its own message as an `inline` error. This includes the missing confirmation. The screen
  selector shows this as "Set up refused: every broken rule named".
- *Created*: a success banner. In the real app this navigates away.

**Decided while drafting:** the refusal is shown twice, once as a summary banner and once against
each field. The brief only says "name every broken rule".

## 2. Log in (Login_Screen)

**For:** every member logs in with username and password (Requirement 4).

**In:** the app's entry screen once a family exists, after logout, and after a session is ended by
a reset, a password change or a deactivation.
**Out:** success opens the Home_View; "Create a kid account" opens screen 3.

**Fields:** Username, Password. **Actions:** Log in, a link to kid registration, and a static line:
"Forgot your password? Ask a parent to set a new one" (decision 8).

**States:** one `banner` above the form. Its message depends on the outcome:
- wrong credentials: "Username or password incorrect." (generic, decision 10);
- pending registration: "A parent has not approved your account yet." (selector state);
- rejected registration: "A parent rejected your registration. You can register again with the
  same username." (decision 19);
- deactivated account: "This account is deactivated. Ask a parent to reactivate it.";
- locked: "Too many attempts. Try again at 16:42, in 15 minutes." (selector state; Requirement 4.8
  asks to "say when to try again", and the mockup shows both a clock time and a duration).

The mockup does not check passwords. Any password counts as matching for a username in the
fixtures, and an unknown username fails and counts toward the five-attempt lockout.

## 3. Kid registers (Registration_Screen)

**For:** a kid asks for an account (Requirement 2).

**In:** from the login screen's "Create a kid account" link, only while a family exists.
**Out:** "I already have an account" goes back to log in.

**Fields:** Username, Display name, Password. **Actions:** Ask to join.

**States:**
- *Empty*.
- *Refused*: the same summary banner plus per-field errors as setup. It adds "That username is
  taken" when a member or a **pending** registration holds the name, ignoring case. A rejected
  registration's name is free (decision 4).
- *Sent*: "Your account mila_08 is waiting for a parent to approve it. You can log in once they
  have." (Requirement 2.3; selector state "Kid registered: waiting for a parent").

**Decided while drafting:** the confirmation replaces the form instead of sending the kid back to
log in, so they cannot miss it.

## 4. Parent top bar (on every parent screen)

**For:** shows the pending-registrations count badge to every active parent (Requirement 3.3).

**Content:** the app name, "New registrations" with an `info` badge holding the pending count
(hidden at zero), "Family members", "Change password", and "Log out <name>".

**Decided while drafting:** the brief requires the badge but not where it lives. The mockup puts it
on a parent-only top bar, which is the one place a parent always sees it. The inventory has no
navigation or app-bar component, so this bar is composed from `button` and `badge`. The kid's
equivalent is undefined (see open questions).

## 5. Parent home (Home_View, parent)

**For:** the first screen after a parent logs in. Its real content belongs to later themes.

**Content:** the top bar with the badge, and an `info` banner "2 kids are waiting for you to
approve their account. Review them". The banner is shown only while anything is pending.
**Out:** to new registrations, family members, change password, log out.

## 6. New registrations (Pending_Registrations_List)

**For:** a parent approves or rejects kids' registrations (Requirement 3).

**In:** from the top bar's badge button or the home banner.

**Content:** a `list`, **oldest first**, one row per pending registration with Display name,
Username and "Asked on <date>", plus **Approve** (primary) and **Reject** (secondary).

**States:**
- *Filled* (fixtures: Mila 20 Nov, Teddy 22 Nov).
- *After a decision*: the row leaves the list and the badge count drops. A success banner says
  "Mila can now log in as mila_08". A rejection banner says "…was rejected. The username … is free
  again."
- *Empty*: "Nobody is waiting." The badge disappears (selector state).

**Not mocked:** Requirement 3.6, the refusal when another parent already decided the registration
("already approved" / "already rejected"). It would appear in the same banner slot.
**Decided while drafting:** Reject has no confirmation dialog. It is cheap to undo, because the kid
can register again.

## 7. Family members (Members_List)

**For:** a parent sees everyone and manages access (Requirements 5–7).

**In:** from the top bar. **Out:** "Add a parent" (screen 8).

**Content:** a `table` with Name, Username, Role (`neutral` badge), Status (`success` Active /
`warning` Deactivated) and per-row actions: **Set new password**, and **Deactivate** or
**Reactivate**.

**States and dialogs:**
- *Deactivate*: a `modal` confirmation that says the member is logged out everywhere and that their
  chores and points history stay. It has a danger button. After it, the row shows Deactivated and
  stays in the list (Requirement 7.2).
- *Last active parent*: deactivating the only remaining active parent is refused in an error banner,
  "The family needs at least one active parent." (decision 16).
- *Reactivate*: immediate, no dialog, with a success banner saying the member can log in again with
  their existing password.
- *Set new password* (selector state "Family members: set a new password"): a `modal` with one New
  password field. It says the member is logged out on every device, that any lockout is lifted, and
  that the parent tells them the password themself (Requirement 6.5–6.6, decision 8).

**Decided while drafting:** deactivate is confirmed but reactivate is not. The reset dialog has no
"confirm password" field, because the brief has none.

## 8. Add a parent

**For:** a parent creates another parent's account, active immediately (Requirement 5, decision 3).

**In:** from Family members. **Out:** Cancel returns there.

**Fields:** Username, Display name, First password. **Actions:** Create parent account.
**States:** refused (the same rule summary, plus "That username is taken"), and created ("Jonas is
now a parent and can log in as jonas_v").

**Decided while drafting:** this is a full screen, not a dialog, because it has three fields and a
rule summary.

## 9. Change your own password

**For:** any member, parent or kid, replaces their password (Requirement 6.1–6.4).

**In:** "Change password" in the top bar (for parents; the kid's way in is undefined).
**Out:** Cancel returns home.

**Fields:** Current password, New password. **States:** wrong current password ("That is not your
current password"), new password too short, and changed ("Your other devices are logged out",
decision 21). The screen tells the user up front that this device stays logged in and others are
logged out.

---

## Open questions for shaping

- **The kid's home and top bar.** The brief defines no kid-facing chrome. Where does a kid reach
  "Change password" and "Log out"?
- **Badge placement.** Is a parent top bar the right home for the pending count, or should it be on
  the Home_View only?
- **Rejected registrations.** They are "kept on record", but no screen shows them to a parent.
  Should Members or New registrations have a history?
- **Lockout wording.** Should it show a clock time, a duration, or both?
- **Confirm-password fields.** None of the forms ask for the password twice, because the brief does
  not. Kids typing on phones may need it.
