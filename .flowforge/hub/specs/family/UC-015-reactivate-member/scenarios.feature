Feature: Reactivate a member
  As a parent
  I want to reactivate a deactivated family member
  So that they can use the family space again with their history intact

  Background:
    Given the family exists with active parent "Sanne_V" with token "sanne-token-1"
    And deactivated kid "Jip_2015" with id "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81", password "voetbal2015" and old token "jip-telefoon"

  @happy-path
  Scenario: Successful reactivation lets the member log in again
    When the app reactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1"
    Then the response status is 200
    And the response contains a family member with username "Jip_2015" and status "active"
    And the member's status is active
    And the member can log in again with username "Jip_2015" and the existing password "voetbal2015"
    And sessions ended by the deactivation stay ended, so token "jip-telefoon" is not accepted

  @edge-case
  Scenario: Edge case — a reactivated parent counts as an active parent again
    Given deactivated parent "Joris_V" with id "6c8e0a2b-4d6f-4a8c-9e1b-3d5f7a9c1e3b"
    When the app reactivates member "6c8e0a2b-4d6f-4a8c-9e1b-3d5f7a9c1e3b" with token "sanne-token-1"
    Then the response status is 200
    And "Sanne_V" can now be deactivated because "Joris_V" is an active parent

  @error
  Scenario: Reactivating an active member is a conflict
    Given "Jip_2015" is active
    When the app reactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "sanne-token-1"
    Then the response status is 409 with error code "CONFLICT_MEMBER_ALREADY_ACTIVE"
    And the error message is "This member is already active."

  @error
  Scenario: Kid is denied reactivating a member
    Given active kid "Roos_K" has token "roos-token-1"
    When the app reactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" with token "roos-token-1"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And "Jip_2015" stays deactivated

  @error
  Scenario: Reactivation without a session token is unauthenticated
    When the app reactivates member "4e2a9c7b-1d5f-4b3a-8c6e-9a0b2d4f6e81" without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @error
  Scenario: Reactivating an unknown member is not found
    When the app reactivates member "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d" with token "sanne-token-1"
    Then the response status is 404 with error code "NOT_FOUND_MEMBER"
    And the error message is "That family member does not exist."
