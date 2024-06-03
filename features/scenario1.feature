Feature: Lock works properly

  Scenario: Scenario 1
    Given contract is deployed
    And has been funded 5000 LSK for 500 days
    And 7 stakers with balance of 500 LSK
    And has been funded
    And on day 1
    And staker 1 stakes 100 LSK for 30 days
    And staker 2 stakes 100 LSK for 80 days
    And on day 10
    And staker 3 stakes 100 LSK for 100 days
    And on day 30
    And staker 2 pauses stake
    Then pending unlock amount should be consistent
    Given on day 35
    And staker 4 stakes 50 LSK for 14 days
    Then pending unlock amount should be consistent
    Given on day 49
    And staker 4 unlocks stake
    Then pending unlock amount should be consistent
    And staker 5 stakes 80 LSK for 80 days
    Then pending unlock amount should be consistent
    Given on day 50
    And staker 1 extends by 50 days
    And on day 70
    And staker 6 stakes 100 LSK for 150 days
    Then pending unlock amount should be consistent
    And on day 80
    And staker 2 resumes stake
    And on day 89
    And staker 5 pauses stake
    And on day 95
    And staker 6 stakes 200 LSK for 95 days
    Then pending unlock amount should be consistent
    Given on day 100
    And staker 6 increases amount by 50 LSK
    Then pending unlock amount should be consistent
    # Then on day 1
    # Then on day 13
    # When when 1
    # Given given 1
    # Then then 1
