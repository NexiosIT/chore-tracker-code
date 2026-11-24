Feature: List family members
  As a parent
  I want to see every family member with their role and status
  So that I can manage who uses the family space

  Background:
    Given the family exists with active parent "Sanne_V" with display name "Mama" and token "sanne-token-1"
    And active parent "Joris_V" with display name "Papa"
    And active kid "Roos_K" with display name "Roos"
    And deactivated kid "Jip_2015" with display name "Jip" and token "jip-token-1"

  @happy-path
  Scenario: Successful list of every family member with role and status
    When the app lists members with token "sanne-token-1"
    Then the response status is 200
    And the response returns every family member, active and deactivated, with id, display name, username, role and status
    And parents come first, then kids, each ordered by display name: "Mama", "Papa", "Jip", "Roos"
    And "Jip_2015" is listed with status "deactivated"
    And nothing is changed

  @edge-case
  Scenario: Edge case — equal display names are ordered by username
    Given active kid "Sam_B" with display name "Sam" and active kid "Sam_A" with display name "Sam"
    When the app lists members with token "sanne-token-1"
    Then "Sam_A" is listed before "Sam_B"

  @error
  Scenario: Kid is denied the members list
    Given active kid "Roos_K" has token "roos-token-1"
    When the app lists members with token "roos-token-1"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"

  @error
  Scenario: Request without a session token is unauthenticated
    When the app lists members without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
