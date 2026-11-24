Feature: Reject a registration
  As a parent
  I want to reject a kid's pending registration
  So that only my own kids can join the family

  Background:
    Given the family exists with active parents "Sanne_V" with token "sanne-token-1" and "Joris_V" with token "joris-token-1"
    And active kid "Jip_2015" with token "jip-token-1"
    And a pending registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" for "Onbekend_9" with display name "Gast" and password "probeer1234"

  @happy-path
  Scenario: Successful rejection keeps the record and frees the username
    When the app rejects registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" with token "sanne-token-1"
    Then the response status is 200
    And the response contains a registration with username "Onbekend_9" and status "rejected"
    And the registration is marked rejected, is kept on record, and is no longer in the pending list
    And the username "Onbekend_9" is freed for a new registration
    And no family member is created
    And the registration records the deciding parent "Sanne_V" and the decision time

  @edge-case
  Scenario: Edge case — the rejected kid is told at login
    Given registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" was rejected
    When someone logs in with username "Onbekend_9" and password "probeer1234"
    Then the response status is 403 with error code "AUTHORIZATION_REGISTRATION_REJECTED"

  @edge-case
  Scenario: Concurrent reject and approve decide the registration only once
    When "Sanne_V" rejects and "Joris_V" approves registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" at the same moment
    Then exactly one decision succeeds
    And the other gets response status 409 naming the decision that won

  @error
  Scenario: Rejecting an already rejected registration is a conflict
    Given registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" was rejected
    When the app rejects registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" with token "joris-token-1"
    Then the response status is 409 with error code "CONFLICT_REGISTRATION_ALREADY_REJECTED"
    And the error message is "This registration was already rejected."

  @error
  Scenario: Rejecting an approved registration is a conflict
    Given registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" was approved
    When the app rejects registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" with token "sanne-token-1"
    Then the response status is 409 with error code "CONFLICT_REGISTRATION_ALREADY_APPROVED"
    And the error message is "This registration was already approved."

  @error
  Scenario: Kid is denied rejecting a registration
    When the app rejects registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" with token "jip-token-1"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And the registration is still pending

  @error
  Scenario: Rejection without a session token is unauthenticated
    When the app rejects registration "5c3d2e1f-0a9b-4c8d-8e7f-6a5b4c3d2e1f" without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"

  @error
  Scenario: Rejecting an unknown registration is not found
    When the app rejects registration "9f0e8d7c-6b5a-4f3e-8d2c-1b0a9f8e7d6c" with token "sanne-token-1"
    Then the response status is 404 with error code "NOT_FOUND_REGISTRATION"
    And the error message is "That registration does not exist."
