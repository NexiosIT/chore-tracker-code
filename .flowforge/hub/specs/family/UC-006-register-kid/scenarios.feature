Feature: Register as a kid
  As a kid
  I want to create my own account with a username and password
  So that I can start using the app once a parent lets me in

  Username: 3 to 20 letters, digits or underscores, stored as typed, unique ignoring
  case across family members and pending registrations.
  Display name: 1 to 30 characters after leading and trailing spaces are removed.
  Password: 8 to 64 characters, no composition rules.

  Background:
    Given the family exists with active parents "Sanne_V" and "Joris_V"
    And active kid "Jip_2015"

  @happy-path
  Scenario: Successful kid registration stays pending
    Given the time is 16:05 on 23 November 2026
    When a kid registers with username "Roos_K", display name "Roos" and password "roosje2016"
    Then the response status is 201
    And the response contains a registration with username "Roos_K", display name "Roos", status "pending" and requestedAt "2026-11-23T16:05:00Z"
    And a registration with status pending exists for "Roos_K" with a hashed password
    And the registration's username "Roos_K" is reserved
    And the pending registration appears in the pending registrations list of "Sanne_V" and of "Joris_V"
    And no family member and no session is created

  @edge-case
  Scenario: Edge case — a username from a rejected registration is reused
    Given a registration for "Roos_K" was rejected
    When a kid registers with username "roos_k", display name "Roos" and password "nieuwepoging3"
    Then the response status is 201
    And the response contains a registration with username "roos_k" and status "pending"

  @edge-case
  Scenario: Concurrent registrations for the same username create only one
    When two kids register with username "Lars_7" and "LARS_7" at the same moment
    Then exactly one registration gets response status 201
    And the other gets response status 409 with error code "CONFLICT_USERNAME_TAKEN"

  @error
  Scenario: Username already used by a family member is a conflict
    When a kid registers with username "JIP_2015", display name "Jip" and password "voetbal2015"
    Then the response status is 409 with error code "CONFLICT_USERNAME_TAKEN"
    And the error message is "That username is taken. Choose another one."
    And no registration is created

  @error
  Scenario: Username reserved by a pending registration is a conflict
    Given a pending registration for "Roos_K"
    When a kid registers with username "roos_K", display name "Roosje" and password "anderwoord8"
    Then the response status is 409 with error code "CONFLICT_USERNAME_TAKEN"
    And the error message is "That username is taken. Choose another one."

  @error
  Scenario: Invalid input fails with every broken rule named
    When a kid registers with username "R K", display name "", password "1234567"
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "username" with rule "pattern" and message "Username can only use letters, digits and underscores"
    And the error details name field "displayName" with rule "length" and message "Display name needs 1 to 30 characters"
    And the error details name field "password" with rule "minLength" and message "Password needs at least 8 characters"
    And no registration is created

  @error
  Scenario: Registration fails while no family exists
    Given no family exists
    When a kid registers with username "Roos_K", display name "Roos" and password "roosje2016"
    Then the response status is 422 with error code "BUSINESS_FAMILY_NOT_SET_UP"
    And the error message is "The family is not set up yet. A parent has to set it up first."
    And no registration is created
