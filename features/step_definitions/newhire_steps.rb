def people_for_newhire
  return @a if defined?(@a)
  @a = {
    "Jack Ivl" => {
      first_name: "Jack",
      last_name: "Ivl",
      dob: "08/10/1960",
      ssn: "196008107",
      email: "jack@ivl.com",
      password: 'aA1!aA1!aA1!'

    },
    "Jack Doe" => {
      first_name: "Jack",
      last_name: "Doe",
      dob: '10/11/1978',
      legal_name: "BestLife",
      dba: "BestLife",
      fein: "050000000",
      ssn: "197810118",
      email: "jack@dc.gov",
      password: 'aA1!aA1!aA1!'
    },
  }
end

When(/^(.*) create a new account$/) do |named_person|
  person = people_for_newhire[named_person]
  fill_in "user[email]", :with => person[:email]
  fill_in "user[password]", :with => person[:password]
  fill_in "user[password_confirmation]", :with => person[:password]
  screenshot("create_account")
  find(".interaction-click-control-create-account").click
end

When(/^I clicks on continue button for individual$/) do
  find('.interaction-click-control-continue').click
end

When(/^.+ click special continue button$/) do
  find('span.btn-primary').trigger('click')
  sleep(1)
end

Then(/^I should see the individual register page$/) do
  expect(page).to have_content("Personal Information")
end

When(/I should click continue button for verfify person info/) do
  find('.interaction-click-control-continue').click
end

When(/^(.*) goes to register as an individual for newhire$/) do |named_person|
  person = people_for_newhire[named_person]
  fill_in "person[first_name]", :with => person[:first_name]
  fill_in "person[last_name]", :with => person[:last_name]
  fill_in "jq_datepicker_ignore_person[dob]", :with => person[:dob]
  fill_in "person[ssn]", :with => person[:ssn]
  find(:xpath, '//label[@for="radio_male"]').click
  screenshot("register")
end

Then(/^.+ should see successful msg/) do
  expect(page).to have_content('Thank you. Next, we need to verify if you or you and your family are eligible to enroll in coverage through DC Health Link. Please select CONTINUE.')
end

Then(/^Jack Ivl should see confirm page$/) do
  expect(page).to have_content('Confirm Your Plan Selection')
end

When(/^Jack Ivl click on continue button on confirm page$/) do
  find('.interaction-choice-control-value-terms-check-thank-you').click
  fill_in 'first_name_thank_you', :with => 'Jack'
  fill_in 'last_name_thank_you', :with => 'Ivl'
  click_link "Confirm"
end

Then(/Jack Ivl should see recipient page/) do
  expect(page).to have_content("Enrollment Submitted")
end

And(/^.+ should see employer census family created success message for (.*)$/) do |named_person|
  sleep(1)
  person = people_for_newhire[named_person]
  expect(page).to have_content('Census Employee is successfully created.')
  screenshot("employer_census_new_family_success_message")
  expect(page).to have_content(person[:first_name])
  expect(page).to have_content(person[:last_name])
end

Then(/^I should see the page of group selection$/) do
  expect(page).to have_content('Choose Coverage for your Household')
end

Then(/^I should see the page of plan shopping$/) do
  expect(page).to have_content('Choose Plan')
end

And(/^.+ should be able to enter plan year, benefits, relationship benefits$/) do
  find(:xpath, "//p[@class='label'][contains(., 'SELECT START ON')]").click
  find(:xpath, "//li[@data-index='1'][contains(., '#{Date.today.year}')]").click

  screenshot("employer_add_plan_year")
  find('.interaction-field-control-plan-year-fte-count').click

  fill_in "plan_year[fte_count]", :with => "35"
  fill_in "plan_year[pte_count]", :with => "15"
  fill_in "plan_year[msp_count]", :with => "3"

  find('.interaction-click-control-continue').click

  # Benefit Group
  fill_in "plan_year[benefit_groups_attributes][0][title]", :with => "Silver PPO Group"

  find('.interaction-choice-control-plan-year-start-on').click
  find('li.interaction-choice-control-plan-year-start-on-1').click

  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][0][premium_pct]", :with => 50
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][1][premium_pct]", :with => 50
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][2][premium_pct]", :with => 50
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][3][premium_pct]", :with => 50

  find(:xpath, '//li/label[@for="plan_year_benefit_groups_attributes_0_plan_option_kind_single_carrier"]').click
  sleep 1 #Four back to back clicks causes intermittent failures.  Make sure the page setup/DOM load is complete
  find('.carriers-tab a').click
  sleep 1 #maybe some work here
  find('.reference-plans label').click
  sleep 1
  find('.interaction-click-control-create-plan-year').trigger('click')
end

And(/Employer should see the status of employee role linked/) do
  expect(page).to have_content("Employee Role Linked")
end

When(/^.+ click sign in existing account$/) do
  find('.interaction-click-control-sign-in-existing-account').click
  click_link "Sign In Existing Account"
end

Then(/^.+ should see sign in page/) do
  expect(page).to have_content('Sign In')
  expect(page).not_to have_content('Sign In Existing Account')
end

When(/^(.*) login to the Insured portal$/) do |named_person|
  person = people_for_newhire[named_person]

  fill_in "user[login]", :with => person[:email]
  find('#user_login').set(person[:email])
  fill_in "user[password]", :with => person[:password]
  find('.interaction-click-control-sign-in').click
end

Then(/I should see a successful sign in message/) do
  expect(page).to have_content('Signed in successfully.')
end

And(/I should see employer hire message/) do
  expect(page).to have_content("Congratulations on your new job at BestLife.")
  find(".interaction-click-control-shop-for-employer-sponsored-coverage").click
end

And(/I should not see employer hire message/) do
  expect(page).not_to have_content("Congratulations on your new job at BestLife.")
end

And(/^Jack Ivl click on continue button on group selection page after hired by employer$/) do
  find(".interaction-click-control-continue", wait: 10).click
  wait_for_ajax(10)
  find('.plan-select', :wait => 10)
end

Then(/^Employer should see a form to enter information about employee, address and dependents details for Jack Ivl$/) do
  person = people_for_newhire['Jack Ivl']
  # Census Employee
  fill_in 'census_employee[first_name]', with: person[:first_name]
  fill_in 'census_employee[last_name]', with: person[:last_name]
  find(:xpath, "//p[contains(., 'NONE')]").click
  find(:xpath, "//li[contains(., 'Jr.')]").click

  fill_in 'jq_datepicker_ignore_census_employee[dob]', :with => person[:dob]
  fill_in 'census_employee[ssn]', :with => person[:ssn]

  find(:xpath, "//label[@for='radio_male']").click

  fill_in 'jq_datepicker_ignore_census_employee[hired_on]', :with => (TimeKeeper.date_of_record - 10.days).to_s

  find(:xpath, "//div[div/select[@name='census_employee[benefit_group_assignments_attributes][0][benefit_group_id]']]//p[@class='label']").click
  find(:xpath, "//div[div/select[@name='census_employee[benefit_group_assignments_attributes][0][benefit_group_id]']]//li[@data-index='1']").click

  # Address
  fill_in 'census_employee[address_attributes][address_1]', :with => "1026 Potomac"
  fill_in 'census_employee[address_attributes][address_2]', :with => "Apt ABC"
  fill_in 'census_employee[address_attributes][city]', :with => "Alpharetta"

  find(:xpath, "//p[@class='label'][contains(., 'SELECT STATE')]").click
  find(:xpath, "//li[contains(., 'GA')]").click

  fill_in 'census_employee[address_attributes][zip]', :with => "30228"

  find(:xpath, "//p[contains(., 'SELECT KIND')]").click
  find(:xpath, "//li[@data-index='1'][contains(., 'home')]").click

  fill_in 'census_employee[email_attributes][address]', :with => person[:email]

  screenshot("create_census_employee_with_data")
  click_button "Create Employee"
end
