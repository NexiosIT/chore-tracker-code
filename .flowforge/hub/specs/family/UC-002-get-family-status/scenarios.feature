Feature: Get family status
  As the app on a device where nobody is logged in
  I want to know whether the family exists
  So that I offer the Setup screen on a fresh install and the Login screen otherwise

  A family exists once any family member exists, whatever its role or status.
  The call is anonymous and reveals nothing about the members.

  @happy-path
  Scenario: Successful status read once the family exists
    Given a family exists with active parent "Sanne_V"
    When the app requests the family status without a session token
    Then the response status is 200
    And the response has familyExists true, which tells that the family exists
    And the response contains no member details
    And nothing is changed

  @happy-path
  Scenario: Successful status read on a fresh install
    Given no family exists
    When the app requests the family status without a session token
    Then the response status is 200
    And the response has familyExists false

  @edge-case
  Scenario: Edge case — a family whose only parent is deactivated still exists
    Given a family exists with only deactivated parent "Sanne_V" and active kid "Jip_2015"
    When the app requests the family status without a session token
    Then the response status is 200
    And the response has familyExists true

  @error
  Scenario: Invalid session token does not fail the anonymous status read
    Given a family exists with active parent "Sanne_V"
    When the app requests the family status with the ended session token "oud-token-123"
    Then the response status is 200
    And the response has familyExists true

  @error
  Scenario: Storage failure returns a generic internal error
    Given the family data cannot be read because the database is unavailable
    When the app requests the family status without a session token
    Then the response status is 500 with error code "INTERNAL_ERROR"
    And the error message is "Something went wrong. Try again later."
    And the error message reveals no database detail
