Feature: Change own password
  As a family member
  I want to change my own password by giving my current one
  So that I control my own login without asking a parent

  New password: 8 to 64 characters, no composition rules.

  Background:
    Given the family exists with active parent "Sanne_V"
    And active kid "Jip_2015" with password "voetbal2015"
    And "Jip_2015" has a session with token "telefoon-token-1" on his phone and "tablet-token-1" on the tablet

  @happy-path
  Scenario: Successful password change keeps this session and ends the others
    When the app changes the password with token "telefoon-token-1", current password "voetbal2015" and new password "keeper2026"
    Then the response status is 204
    And the password of "Jip_2015" is replaced, so he can log in with "keeper2026" and not with "voetbal2015"
    And the session used for the change with token "telefoon-token-1" is kept
    And all other sessions are ended, so token "tablet-token-1" is no longer accepted
    And each ended session is removed and a session end record is written with the member, the session's start time, the end time and reason "password-change"

  @edge-case
  Scenario: Boundary — a new password of exactly 8 characters is accepted
    When the app changes the password with token "telefoon-token-1", current password "voetbal2015" and new password "12345678"
    Then the response status is 204

  @error
  Scenario: Wrong current password is invalid
    When the app changes the password with token "telefoon-token-1", current password "verkeerd123" and new password "keeper2026"
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "currentPassword" with rule "matches" and message "Your current password is incorrect"
    And the password is unchanged and token "tablet-token-1" is still accepted

  @error
  Scenario: Too short new password is invalid
    When the app changes the password with token "telefoon-token-1", current password "voetbal2015" and new password "kort12"
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "newPassword" with rule "minLength" and message "Password needs at least 8 characters"

  @error
  Scenario: Too long new password is invalid
    When the app changes the password with token "telefoon-token-1", current password "voetbal2015" and a new password of 65 characters
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "newPassword" with rule "maxLength" and message "Password can have at most 64 characters"

  @error
  Scenario: Change without a session token is unauthenticated
    When the app changes the password without a session token, current password "voetbal2015" and new password "keeper2026"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @edge-case
  Scenario: Concurrent login with the old password and password change leave no extra session
    When someone logs in as "Jip_2015" with password "voetbal2015" and the app changes the password with token "telefoon-token-1", current password "voetbal2015" and new password "keeper2026" at the same moment
    Then the change gets response status 204
    And the login gets either response status 201 or response status 401 with error code "AUTHENTICATION_FAILED"
    And the only session "Jip_2015" holds afterwards is the one with token "telefoon-token-1"
