Feature: Log out
  As a logged-in family member
  I want to log out on this device
  So that nobody else can use my account on it

  Background:
    Given the family exists with active parent "Sanne_V"
    And active kid "Jip_2015" has a session with token "telefoon-token-1" on his phone
    And "Jip_2015" has a session with token "tablet-token-1" on the tablet

  @happy-path
  Scenario: Successful logout ends only this device's session
    When the app logs out with token "telefoon-token-1"
    Then the response status is 204
    And the session used for the call has ended, so token "telefoon-token-1" is no longer accepted
    And each ended session is removed and a session end record is written with the member, the session's start time, the end time and reason "logout"
    And the session with token "tablet-token-1" on other devices is unaffected

  @edge-case
  Scenario: Edge case — logging out twice gives an ended-session answer
    Given the app has logged out with token "telefoon-token-1"
    When the app logs out with token "telefoon-token-1" again
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
    And the session with token "tablet-token-1" still exists

  @error
  Scenario: Logout without a session token is unauthenticated
    When the app logs out without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
    And the error message is "Your session has ended. Log in again."

  @error
  Scenario: Logout with an invalid token is unauthenticated
    When the app logs out with token "verzonnen-token-9"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
    And no session is ended
