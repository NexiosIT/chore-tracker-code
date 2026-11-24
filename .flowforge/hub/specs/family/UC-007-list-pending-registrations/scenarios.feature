Feature: List pending registrations
  As a parent
  I want to see every pending kid registration and how many there are
  So that I can approve or reject them and notice new ones from the badge

  Background:
    Given the family exists with active parent "Sanne_V" with session token "sanne-token-1"
    And active kid "Jip_2015" with session token "jip-token-1"

  @happy-path
  Scenario: Successful list of pending registrations, oldest first, with count
    Given a pending registration for "Roos_K" with display name "Roos" requested at "2026-11-23T16:05:00Z"
    And a pending registration for "Lars_7" with display name "Lars" requested at "2026-11-22T09:30:00Z"
    And a rejected registration for "Mila_1" requested at "2026-11-21T10:00:00Z"
    When the app lists pending registrations with token "sanne-token-1"
    Then the response status is 200
    And the response returns every pending registration, oldest first: "Lars_7" then "Roos_K"
    And each registration has its username, display name and requested time
    And the response returns the count of pending registrations as 2
    And nothing is changed

  @edge-case
  Scenario: Empty list when nothing is pending
    When the app lists pending registrations with token "sanne-token-1"
    Then the response status is 200
    And the response has no registrations and count 0

  @edge-case
  Scenario: Edge case — registrations requested at the same moment are ordered by username
    Given pending registrations for "Mila_1" and "Bo_22" both requested at "2026-11-23T08:00:00Z"
    When the app lists pending registrations with token "sanne-token-1"
    Then the registrations are ordered "Bo_22" then "Mila_1"

  @error
  Scenario: Kid is denied the pending list
    When the app lists pending registrations with token "jip-token-1"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And the error message is "Only a parent can do this."

  @error
  Scenario: Request without a session token is unauthenticated
    When the app lists pending registrations without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
