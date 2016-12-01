Feature: User has dual roles (consumer & employee)
  Scenario: Add employee_role after employer added and match to current individual
    Given Individual has not signed up as an HBX user
    When Individual visits the Insured portal during open enrollment
    Then Individual John Wood creates HBX account
    Then I should see a successful sign up message
    And user should see your information page
    When Individual John Wood goes to register as an individual
    When user clicks on continue button
    Then user should see heading labeled personal information
    Then Individual should click on Individual market for plan shopping
    Then Individual should see a form to enter personal information
    Then Individual sees previously saved address
    Then Individual agrees to the privacy agreeement
    Then Individual should see identity verification page and clicks on submit
    Then Individual should see the dependents form
    And I click on continue button on household info form
    Then I should see the group selection page
    When I visit family home page
    And I should see the individual home page
    Then Individual logs out

    Given Employer Soren White with a published health plan year
    And Employer Soren White login
    When Employer clicks on the Employees tab
    When Employer clicks on the add employee button
    Then Employer should see a form to enter information about employee, address and dependents details for John Wood
    And Employer should see employee John Wood created success message
    Then Employer logs out

    When Individual John Wood logins to the Consumer Portal
    And I should see the individual home page
    And I should see the employer congratulation message
    When I click on the button of shop for plans
    Then I should see the group selection page
    And I click on continue button on group selection page
    And I select three plans to compare
    And I should not see any plan which premium is 0
    And I select a plan on plan shopping page
    When I clicks on Confirm button on the coverage summary page
    Then I should see the receipt page
    And I should see the individual home page
