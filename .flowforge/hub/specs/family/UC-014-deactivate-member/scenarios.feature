Feature: Deactivate a member
  As a parent
  I want to deactivate a family member's account
  So that I control who can use the family space without losing anyone's history

  Background:
    Given the family exists with active parent "Sanne_V" with id "1f3e5a7c-9b2d-4e6f-8a1c-3e5b7d9f1a2c" and token "sanne-token-1"
    And active parent "Joris_V" with id "6c8e0a2b-4d6f-4a8c-9e1b-3d5f7a9c1e3b" and token "joris-token-1"
    And active kid "Jip_2015" with id "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81", sessions "jip-telefoon" and "jip-tablet"

  @happy-path
  Scenario: Successful deactivation keeps the data and ends every session
    When the app deactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1"
    Then the response status is 200
    And the response contains a family member with username "Jip_2015" and status "deactivated"
    And the member's status is deactivated and none of their data is deleted
    And all sessions of the member are ended, so tokens "jip-telefoon" and "jip-tablet" get 401 "AUTHENTICATION_REQUIRED" on their next action and the app shows the Login screen
    And each ended session is removed and a session end record is written with the member, the session's start time, the end time and reason "deactivation"
    And the member stays in the members list with status "deactivated"

  @edge-case
  Scenario: Edge case — a parent deactivates themselves while another parent is active
    When the app deactivates member "1f3e5a7c-9b2d-4e6f-8a1c-3e5b7d9f1a2c" with token "sanne-token-1"
    Then the response status is 200
    And token "sanne-token-1" is no longer accepted

  @edge-case
  Scenario: Concurrent deactivation of the last two parents leaves one active
    When "Sanne_V" deactivates "Joris_V" and "Joris_V" deactivates "Sanne_V" at the same moment
    Then exactly one deactivation gets response status 200
    And the other gets response status 422 with error code "BUSINESS_LAST_ACTIVE_PARENT"
    And exactly one active parent remains

  @edge-case
  Scenario: Concurrent login and deactivation leave no live session
    When "Jip_2015" logs in with his correct password and the app deactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1" at the same moment
    Then the deactivation gets response status 200
    And the login gets either response status 201 or response status 403 with error code "AUTHORIZATION_ACCOUNT_DEACTIVATED"
    And "Jip_2015" has no session afterwards, so any token the login returned gets 401 "AUTHENTICATION_REQUIRED"

  @error
  Scenario: Deactivating the last active parent is rejected
    Given "Joris_V" is deactivated
    When the app deactivates member "1f3e5a7c-9b2d-4e6f-8a1c-3e5b7d9f1a2c" with token "sanne-token-1"
    Then the response status is 422 with error code "BUSINESS_LAST_ACTIVE_PARENT"
    And the error message is "The family needs at least one active parent."
    And "Sanne_V" stays active

  @error
  Scenario: Deactivating an already deactivated member is a conflict
    Given "Jip_2015" is deactivated
    When the app deactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1"
    Then the response status is 409 with error code "CONFLICT_MEMBER_ALREADY_DEACTIVATED"
    And the error message is "This member is already deactivated."

  @error
  Scenario: Kid is denied deactivating a member
    Given active kid "Roos_K" has token "roos-token-1"
    When the app deactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "roos-token-1"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And "Jip_2015" stays active

  @error
  Scenario: Deactivation without a session token is unauthenticated
    When the app deactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @error
  Scenario: Deactivating an unknown member is not found
    When the app deactivates member "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d" with token "sanne-token-1"
    Then the response status is 404 with error code "NOT_FOUND_MEMBER"
    And the error message is "That family member does not exist."
