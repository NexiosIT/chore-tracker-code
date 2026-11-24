Feature: Log in
  As a family member
  I want to log in with my username and password and stay logged in on my phone
  So that I don't have to type them every time

  The username matches in any case. A session lasts until logout, or until a
  password change, a password reset or a deactivation ends it.
  Failed attempts are counted per submitted username, ignoring case, whether or
  not that username exists. Five consecutive failures lock it for 15 minutes.
  Only an unknown username or a wrong password counts as a failure.

  Background:
    Given the family exists with active parent "Sanne_V" with password "zonnebloem42"
    And active kid "Jip_2015" with display name "Jip" and password "voetbal2015"

  @happy-path
  Scenario: Successful login with the username in another case
    Given the username "Jip_2015" has 3 failed attempts
    When someone logs in with username "jip_2015" and password "voetbal2015"
    Then the response status is 201
    And the response contains a session token
    And the response contains a family member with username "Jip_2015", display name "Jip", role "kid" and status "active"
    And a new session for the member exists and the token identifies "Jip_2015"
    And the failed-attempt count for the username "jip_2015" is reset to zero

  @edge-case
  Scenario: Boundary — login after 4 failures succeeds and resets the count
    Given the username "Sanne_V" has 4 failed attempts
    When someone logs in with username "Sanne_V" and password "zonnebloem42"
    Then the response status is 201
    And the failed-attempt count for the username "Sanne_V" is 0

  @edge-case
  Scenario: Edge case — a second device gets its own session
    Given "Jip_2015" has a session with token "tablet-token-1"
    When someone logs in with username "Jip_2015" and password "voetbal2015"
    Then the response status is 201
    And the session with token "tablet-token-1" still exists

  @edge-case
  Scenario: Edge case — the lockout ends after 15 minutes
    Given the username "Sanne_V" was locked at 14:17 on 23 November 2026
    And the time is 14:32 on 23 November 2026
    When someone logs in with username "Sanne_V" and password "zonnebloem42"
    Then the response status is 201


  @error
  Scenario: Wrong password fails with the generic message
    When someone logs in with username "Jip_2015" and password "verkeerd123"
    Then the response status is 401 with error code "AUTHENTICATION_FAILED"
    And the error message is "Username or password incorrect"
    And the failed-attempt count for the username "Jip_2015" is 1

  @error
  Scenario: Unknown username fails with the same generic message
    When someone logs in with username "Bestaatniet" and password "wat-dan-ook"
    Then the response status is 401 with error code "AUTHENTICATION_FAILED"
    And the error message is "Username or password incorrect"
    And the failed-attempt count for the username "Bestaatniet" is 1

  @error
  Scenario: Pending registration with a matching password is denied
    Given a pending registration for "Roos_K" with password "roosje2016"
    When someone logs in with username "Roos_K" and password "roosje2016"
    Then the response status is 403 with error code "AUTHORIZATION_REGISTRATION_PENDING"
    And the error message is "A parent has not approved your account yet."
    And the failed-attempt count for the username "Roos_K" is unchanged


  @error
  Scenario: Rejected registration with a matching password is denied
    Given a registration for "Roos_K" with password "roosje2016" was rejected
    And no member or pending registration uses the username "Roos_K"
    When someone logs in with username "Roos_K" and password "roosje2016"
    Then the response status is 403 with error code "AUTHORIZATION_REGISTRATION_REJECTED"
    And the error message is "A parent rejected your registration."

  @error
  Scenario: Deactivated member with a matching password is denied
    Given "Jip_2015" is deactivated
    When someone logs in with username "Jip_2015" and password "voetbal2015"
    Then the response status is 403 with error code "AUTHORIZATION_ACCOUNT_DEACTIVATED"
    And the error message is "Your account is deactivated. Ask a parent to reactivate it."
    And no session is started

  @error
  Scenario: The fifth consecutive failure is rejected with a lockout
    Given the username "Sanne_V" has 4 failed attempts
    And the time is 14:17 on 23 November 2026
    When someone logs in with username "Sanne_V" and password "verkeerd123"
    Then the response status is 429 with error code "RATE_LIMIT_LOGIN_LOCKED"
    And the error message is "Too many failed attempts. Try again later."
    And the error has retryAt "2026-11-23T14:32:00Z"
    And the Retry-After header asks the client to wait 15 minutes

  @error
  Scenario: A locked username is rejected even with the right password
    Given the username "Sanne_V" was locked at 14:17 on 23 November 2026
    And the time is 14:25 on 23 November 2026
    When someone logs in with username "sanne_v" and password "zonnebloem42"
    Then the response status is 429 with error code "RATE_LIMIT_LOGIN_LOCKED"
    And the error has retryAt "2026-11-23T14:32:00Z"
    And the Retry-After header asks the client to wait 7 minutes
    And no session is started


  @error
  Scenario: Missing username or password is invalid
    When someone logs in with username "" and password ""
    Then the response status is 400 with error code "VALIDATION_FAILED"
    And the error details name field "username" with rule "required" and message "Enter your username"
    And the error details name field "password" with rule "required" and message "Enter your password"
    And the failed-attempt count for the username "" is not changed
