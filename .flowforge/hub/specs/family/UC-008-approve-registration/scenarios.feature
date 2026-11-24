Feature: Approve a registration
  As a parent
  I want to approve a kid's pending registration
  So that my kid can log in and join the family

  Background:
    Given the family exists with active parents "Sanne_V" with token "sanne-token-1" and "Joris_V" with token "joris-token-1"
    And active kid "Jip_2015" with token "jip-token-1"
    And a pending registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" for "Roos_K" with display name "Roos" and password "roosje2016"

  @happy-path
  Scenario: Successful approval creates an active kid
    When the app approves registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" with token "sanne-token-1"
    Then the response status is 201
    And the response contains a family member with username "Roos_K", display name "Roos", role "kid" and status "active"
    And an active family member with the kid role exists for "Roos_K" with the registration's password hash
    And the registration is marked approved and is no longer in the pending list
    And the kid can log in with username "Roos_K" and the password "roosje2016" chosen at registration
    And the registration records the deciding parent "Sanne_V", the decision time and the id of the member it created

  @edge-case
  Scenario: Concurrent approvals by two parents create only one kid
    When "Sanne_V" and "Joris_V" approve registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" at the same moment
    Then exactly one approval gets response status 201
    And the other gets response status 409 with error code "CONFLICT_REGISTRATION_ALREADY_APPROVED"
    And exactly one family member "Roos_K" exists

  @error
  Scenario: Approving an already approved registration is a conflict
    Given registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" was approved
    When the app approves registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" with token "joris-token-1"
    Then the response status is 409 with error code "CONFLICT_REGISTRATION_ALREADY_APPROVED"
    And the error message is "This registration was already approved."

  @error
  Scenario: Approving a rejected registration is a conflict
    Given registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" was rejected
    When the app approves registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" with token "sanne-token-1"
    Then the response status is 409 with error code "CONFLICT_REGISTRATION_ALREADY_REJECTED"
    And the error message is "This registration was already rejected."
    And no family member "Roos_K" is created

  @error
  Scenario: Kid is denied approving a registration
    When the app approves registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" with token "jip-token-1"
    Then the response status is 403 with error code "AUTHORIZATION_PARENT_ONLY"
    And the registration is still pending

  @error
  Scenario: Approval without a session token is unauthenticated
    When the app approves registration "2b9e4c1a-6d3f-4a8b-9c2e-5f1d7a3b8e40" without a session token
    Then the response status is 401 with error code "AUTHENTICATION_REQUIRED"
    And the registration is still pending

  @error
  Scenario: Approving an unknown registration is not found
    When the app approves registration "9f0e8d7c-6b5a-4f3e-8d2c-1b0a9f8e7d6c" with token "sanne-token-1"
    Then the response status is 404 with error code "NOT_FOUND_REGISTRATION"
    And the error message is "That registration does not exist."
