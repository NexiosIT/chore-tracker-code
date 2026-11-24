Feature: Add a parent
  As a parent
  I want to create an account for my partner
  So that they can manage chores and approvals too

  Username: 3 to 20 letters, digits or underscores, stored as typed, unique ignoring
  case across family members and pending registrations.
  Display name: 1 to 30 characters after leading and trailing spaces are removed.
  Password: 8 to 64 characters, no composition rules.

  Background:
    Given the family exists with active parent "Sanne_V" with token "sanne-token-1"
    And active kid "Jip_2015" with token "jip-token-1"

  @happy-path
  Scenario: Successful creation of an active parent
    When the app adds a parent with token "sanne-token-1", username "Joris_V", display name "Papa" and password "regenboog77"
    Then the response status is 201
    And the response contains a family member with username "Joris_V", display name "Papa", role "parent" and status "active"
    And an active family member with the parent role exists for "Joris_V" with a hashed initial password and no approval step
    And the new parent appears in the members list as an active parent
    And the new parent can log in with username "Joris_V" and the initial password "regenboog77"
    And the session with token "sanne-token-1" is unaffected and no session is started for "Joris_V"

  @edge-case
  Scenario: Edge case — a username freed by a rejected registration can be used
    Given a registration for "Papa_J" was rejected
    When the app adds a parent with token "sanne-token-1", username "papa_j", display name "Papa" and password "regenboog77"
    Then the response status is 201

  @error
  Scenario: Username taken by a pending registration is a conflict
    Given a pending registration for "Roos_K"
    When the app adds a parent with token "sanne-token-1", username "ROOS_K", display name "Oma" and password "omalief1950"
    Then the response status is 409 with error code "CONFLICT_USERNAME_TAKEN"
    And the error message is "That username is taken. Choose another one."

  @error
  Scenario: Username taken by a family member is a conflict
    When the app adds a parent with token "sanne-token-1", username "sanne_v", display name "Sanne" and password "regenboog77"
    Then the response status is 409 with error code "CONFLICT_USERNAME_TAKEN"

  @error
  Scenario: Invalid input fails with every broken rule named
    When the app adds a parent with token "sanne-token-1", username "jo", display name "Papa van Jip, Janneke en Roos!!", password "kort"
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "username" with rule "length" and message "Username needs 3 to 20 characters"
    And the error details name field "displayName" with rule "length" and message "Display name needs 1 to 30 characters"
    And the error details name field "password" with rule "minLength" and message "Password needs at least 8 characters"
    And no family member is created

  @error
  Scenario: Kid is denied adding a parent
    When the app adds a parent with token "jip-token-1", username "Joris_V", display name "Papa" and password "regenboog77"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And no family member is created

  @error
  Scenario: Adding a parent without a session token is unauthenticated
    When the app adds a parent without a session token, username "Joris_V", display name "Papa" and password "regenboog77"
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
