Feature: Reset a member's password
  As a parent
  I want to set a new password for another family member without knowing the old one
  So that nobody is locked out of the family for good

  New password: 8 to 64 characters, no composition rules.

  Background:
    Given the family exists with active parent "Sanne_V" with token "sanne-token-1"
    And active kid "Jip_2015" with id "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81", password "voetbal2015" and token "jip-token-1"
    And active kid "Roos_K" with token "roos-token-1"

  @happy-path
  Scenario: Successful reset ends the member's sessions and clears the lockout
    Given the username "Jip_2015" is locked until 14:32 on 23 November 2026
    And the time is 14:20 on 23 November 2026
    When the app resets the password of member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1" to "nieuwjaar2027"
    Then the response status is 204
    And the target member's password is replaced, so "Jip_2015" can log in with "nieuwjaar2027" at once
    And all sessions of the target member are ended, so token "jip-token-1" is no longer accepted
    And each ended session is removed and a session end record is written with the member, the session's start time, the end time and reason "password-reset"
    And any lockout and failed-attempt count on the username "Jip_2015" is cleared
    And the caller's own sessions are unaffected, so token "sanne-token-1" is still accepted

  @edge-case
  Scenario: Edge case — a deactivated member's password can be reset
    Given "Jip_2015" is deactivated
    When the app resets the password of member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1" to "nieuwjaar2027"
    Then the response status is 204
    And "Jip_2015" stays deactivated

  @error
  Scenario: Parent resetting their own password is rejected
    When the app resets the password of member "Sanne_V" with token "sanne-token-1" to "nieuwjaar2027"
    Then the response status is 422 with error code "BUSINESS_RESET_OWN_PASSWORD"
    And the error message is "Use Change password to change your own password."

  @error
  Scenario: Too short new password is invalid
    When the app resets the password of member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1" to "kort"
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "newPassword" with rule "minLength" and message "Password needs at least 8 characters"
    And token "jip-token-1" is still accepted

  @error
  Scenario: Kid is denied resetting another member's password
    When the app resets the password of member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "roos-token-1" to "nieuwjaar2027"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And the password of "Jip_2015" is unchanged

  @error
  Scenario: Reset without a session token is unauthenticated
    When the app resets the password of member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" without a session token to "nieuwjaar2027"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @error
  Scenario: Resetting an unknown member is not found
    When the app resets the password of member "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d" with token "sanne-token-1" to "nieuwjaar2027"
    Then the response status is 404 with error code "NOT_FOUND_MEMBER"
    And the error message is "That family member does not exist."

  @edge-case
  Scenario: Concurrent login with the old password and reset leave no live session
    When someone logs in as "Jip_2015" with password "voetbal2015" and the app resets the password of member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1" to "nieuwjaar2027" at the same moment
    Then the reset gets response status 204
    And the login gets either response status 201 or response status 401 with error code "AUTHENTICATION_FAILED"
    And "Jip_2015" has no session afterwards, so any token the login returned gets 401 "AUTHENTICATION_REQUIRED"
