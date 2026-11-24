Feature: Get current member
  As a logged-in family member's app
  I want to know whose session this is
  So that I show the right role's screens after a restart and send an ended session to the Login screen

  Background:
    Given the family exists with active parent "Sanne_V" with display name "Mama"
    And active kid "Jip_2015" with display name "Jip" has a session with token "jip-token-1"

  @happy-path
  Scenario: Successful read of the member the session belongs to
    When the app requests the current member with token "jip-token-1"
    Then the response status is 200
    And the response returns the member with username "Jip_2015", display name "Jip", role "kid" and status "active"
    And nothing is changed

  @edge-case
  Scenario: Edge case — a session ended by a parent password reset is refused after app restart
    Given parent "Sanne_V" has reset the password of "Jip_2015"
    When the app requests the current member with token "jip-token-1"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @edge-case
  Scenario: Edge case — reactivation does not revive an ended session
    Given parent "Sanne_V" deactivated "Jip_2015" and then reactivated him
    When the app requests the current member with token "jip-token-1"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @error
  Scenario: Request without a session token is unauthenticated
    When the app requests the current member without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
    And the error message is "Your session has ended. Log in again."

  @error
  Scenario: Session ended by deactivation is unauthenticated
    Given parent "Sanne_V" has deactivated "Jip_2015"
    When the app requests the current member with token "jip-token-1"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
    And the error message is "Your session has ended. Log in again."
