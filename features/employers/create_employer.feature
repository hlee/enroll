@watir @screenshots
Feature: Create Employer
  In order to offer health and dental insurance benefits to my employees, employers must create and manage an account on the HBX for their organization.  Such organizations are referred to as an Employer
  An Employer Representative
  Should be able to create an Employer account

    Scenario: An Employer Representative has not signed up on the HBX
      Given I haven't signed up as an HBX user
      When I visit the Employer portal
        And I sign up with valid user data
      Then I should see a successful sign up message
        And I should see an initial form to enter information about my Employer and myself
      When I go to the benefits tab I should see plan year information
        And I should see a button to create new plan year
        And I should be able to enter plan year, benefits, relationship benefits with high FTE
        And I should see a success message after clicking on create plan year button
      When I click on the Employees tab
      Then I should see the employee family roster
        And It should default to active tab
      When I click on add employee button
      Then I should see a form to enter information about employee, address and dependents details
        And I should see employer census family created success message
      #modify linked employee ssn
      When I click on Edit family button for a census family
        And I edit ssn and dob on employee detail page after linked
        And I should see Access Denied
      #unlinked modify
      When I go back
      And I click on the Employees tab
      And I click on Edit family button for a census family
      Then I should see a form to update the contents of the census employee
        And I should see employer census family updated success message
      #terminate
      #  And I click on the Employees tab
      #  And I click on terminate button for a census family
      #Then The census family should be terminated and move to terminated tab
        #And I should see the census family is successfully terminated message
        #And I logout from employer portal
      #Rehire
      #When I click on Rehire button for a census family on terminated tab
      #Then A new instance of the census family should be created
      #  And I click on the Employees tab
      #  And I click on terminate button for rehired census employee
      When I go to the benefits tab
      Then I should see the plan year
      When I click on publish plan year
      Then I should see Publish Plan Year Modal with warnings
      When I click on the Cancel button
      Then I should be on the Plan Year Edit page with warnings
      When I update the FTE field with valid input and save plan year

      Then I should see a plan year successfully saved message
      When I go to the benefits tab I should see plan year information
      Then I click on publish plan year
      Then I should see a published success message

      When I log out
      Given I do not exist as a user
      And I have an existing employee record
      And I have an existing person record
      When I go to the employee account creation page
      When I enter my new account information
      Then I should be logged in
      When I go to register as an employee
      Then I should see the employee search page
      When I enter the identifying info of Patrick Doe
      Then I should see the matching employee record form
      When I accept the matched employer
      When I complete the matching employee form
      Then I should see the dependents page
      Then I should see 1 dependent
      When I click continue on the dependents page
      Then I should see the group selection page
      When I click continue on the group selection page
      Then I should see the plan shopping welcome page
      Then I should see the list of plans
      When I enter filter in plan selection page
      When I enter combined filter in plan selection page
      Then I should see the combined filter results
      When I select a plan on the plan shopping page
      Then I should see the coverage summary page
      When I click on purchase button on the coverage summary page
      And I click on continue button on the purchase confirmation pop up
      Then I should see the "my account" page
      When I visit consumer profile homepage
      Then I should see the "YOUR LIFE EVENTS" section
      When I click on the plans tab
      Then I should see my plan

    @wip
    Scenario: Employer Representative has previously signed up on HBX
      Given I have signed up previously through consumer, broker agency or previous visit to the Employer portal
      When I visit the Employer portal to sign in
        And I sign in with valid user data
      Then I should see a welcome page with successful sign in message
      #Then I should see fields to search for person and employer
        #And I should see an initial fieldset to enter my name, ssn and dob
        #And My user data from existing the fieldset values are prefilled using data from my existing account
        And I should see a form with a fieldset for Employer information, including: legal name, DBA, fein, entity_kind, broker agency, URL, address, and phone
        And I should see a successful creation message

    @wip
    Scenario: Employer Representative provides a valid FEIN
      Given I complete the Employer initial form with a valid FEIN
      When I submit the form
      Then My form information is saved to the database
        And My FEIN is compared against the list of HBX-registered FEINs
      When My FEIN match succeeds
      Then My record is updated to include Employer Representative Role
        And My Employer's record is created
        And My Employer Role is set as the Employer administrator
        And My Employer's FEIN is linked to my Employer Reprsentative Role
        And I see my Employer's landing page
    @wip
    Scenario: Employer Representative  provides an unrecognized FEIN
      Given I complete the Employer initial form with an invalid FEIN
      When I submit the form
      Then My form information is saved to the database
        And the supplied FEIN is compared against the list of registered FEINs
      When The FEIN match fails
      Then I see a message explaining the error and instructing me to either: correct the FEIN and resubmit, or contact reprentatives at the HBX
