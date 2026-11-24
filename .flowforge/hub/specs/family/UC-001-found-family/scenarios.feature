Feature: Found the family
  As the first parent on a fresh install
  I want to create my account and the family in one step
  So that I can start bringing in the rest of the family

  The first sign-up founds the family as its first parent. A family exists once
  any family member exists, so this path closes after the first success.
  Username: 3 to 20 letters, digits or underscores, stored as typed.
  Display name: 1 to 30 characters after leading and trailing spaces are removed.
  Password: 8 to 64 characters, no composition rules.

  # --- Happy Path ---

  @happy-path
  Scenario: First parent founds the family and is logged in
    Given no family exists
    When a person submits the setup with username "Sanne_V", display name "Mama", password "zonnebloem42" and parent confirmation given
    Then the response status is 201
    And the response contains a family member with username "Sanne_V", display name "Mama", role "parent" and status "active"
    And the response contains a session token
    And the family exists
    And the session token identifies the family member "Sanne_V"

  # --- Edge Cases ---

  @edge-case
  Scenario: Boundary values at the length limits are accepted
    Given no family exists
    When a person submits the setup with username "Sanne_Verhoeven_2026", display name "Mama van Jip, Janneke en Roos!", password "12345678" and parent confirmation given
    Then the response status is 201
    And the response contains a family member with username "Sanne_Verhoeven_2026", display name "Mama van Jip, Janneke en Roos!" and role "parent"

  @edge-case
  Scenario: Edge case — spaces around the display name are removed
    Given no family exists
    When a person submits the setup with username "Sanne_V", display name "  Mama  ", password "zonnebloem42" and parent confirmation given
    Then the response status is 201
    And the response contains a family member with display name "Mama"

  @edge-case
  Scenario: Concurrent setups found only one family
    Given no family exists
    When one person submits the setup as "Sanne_V" and another submits the setup as "Joris_V" at the same moment
    Then exactly one setup gets response status 201
    And the other setup gets response status 409 with error code "CONFLICT_FAMILY_EXISTS"
    And exactly one family member exists

  # --- Error Scenarios ---

  @error
  Scenario: Setup without the parent confirmation fails as invalid
    Given no family exists
    When a person submits the setup with username "Sanne_V", display name "Mama", password "zonnebloem42" and parent confirmation not given
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "parentConfirmed" with rule "mustBeTrue" and message "Confirm that you are a parent setting up this family"
    And no family member exists

  @error
  Scenario: Invalid input fails with every broken rule named
    Given no family exists
    When a person submits the setup with username "s!", display name "", password "kort" and parent confirmation given
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "username" with rule "length" and message "Username needs 3 to 20 characters"
    And the error details name field "username" with rule "pattern" and message "Username can only use letters, digits and underscores"
    And the error details name field "displayName" with rule "length" and message "Display name needs 1 to 30 characters"
    And the error details name field "password" with rule "minLength" and message "Password needs at least 8 characters"
    And no family member exists

  @error
  Scenario: A display name longer than 30 characters is invalid
    Given no family exists
    When a person submits the setup with username "Sanne_V", display name "Mama van iedereen in dit hele huis", password "zonnebloem42" and parent confirmation given
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "displayName" with rule "length" and message "Display name needs 1 to 30 characters"

  @error
  Scenario: A password longer than 64 characters is invalid
    Given no family exists
    When a person submits the setup with username "Sanne_V", display name "Mama" and a password of 65 characters and parent confirmation given
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "password" with rule "maxLength" and message "Password can have at most 64 characters"

  @error
  Scenario: Setup conflicts with an existing family
    Given a family exists with active parent "Sanne_V"
    When a person submits the setup with username "Joris_V", display name "Papa", password "regenboog77" and parent confirmation given
    Then the response status is 409 with error code "CONFLICT_FAMILY_EXISTS"
    And the error message is "This family is already set up. Log in instead."
    And no family member "Joris_V" exists
