When(/^\w+ visit family home page$/) do
  visit '/families/home'
end

When(/^I should see the group selection page$/) do
  expect(page).to have_content "Choose Coverage for your Household"
end

Then(/Individual (.*) creates HBX account$/) do |named_person|
  person = people[named_person]
  click_button 'Create account', :wait => 10
  fill_in "user[oim_id]", :with => person[:email]
  fill_in "user[password]", :with => "aA1!aA1!aA1!"
  fill_in "user[password_confirmation]", :with => "aA1!aA1!aA1!"
  screenshot("create_account")
  click_button "Create account"
end

When(/Individual (.*) goes to register as an individual$/) do |named_person|
  person = people[named_person]
  fill_in 'person[first_name]', :with => person[:first_name]
  fill_in 'person[last_name]', :with => person[:last_name]
  fill_in 'jq_datepicker_ignore_person[dob]', :with => person[:dob]
  fill_in 'person[ssn]', :with => person[:ssn]
  find(:xpath, '//label[@for="radio_male"]').click

  screenshot("register")
  find('.btn', text: 'CONTINUE').click
end

Given(/^Employer (.*) with a published health plan year$/) do |named_person|
  person = people[named_person]
  organization = FactoryGirl.create :organization, legal_name: person[:legal_name], dba: person[:dba], fein: person[:fein]
  employer_profile = FactoryGirl.create :employer_profile, organization: organization
  owner = FactoryGirl.create :census_employee, :owner, employer_profile: employer_profile

  user = FactoryGirl.create :user, :with_family, :employer_staff, email: person[:email], password: '1qaz@WSX', password_confirmation: '1qaz@WSX'
  FactoryGirl.create :employer_staff_role, person: user.person, employer_profile_id: employer_profile.id

  plan_year = FactoryGirl.create :plan_year, employer_profile: employer_profile, fte_count: 2, aasm_state: :published
  benefit_group = FactoryGirl.create :benefit_group, plan_year: plan_year
  FactoryGirl.create(:qualifying_life_event_kind, market_kind: "shop")
  Caches::PlanDetails.load_record_cache!
end

And(/^Employer (.*) login$/) do |named_person|
  person = people[named_person]
  email = person[:email]
  visit "/"
  click_link "Employer Portal"
  find('.interaction-click-control-sign-in-existing-account').click

  fill_in "user[login]", :with => email
  find('#user_login').set(email)
  fill_in "user[password]", :with => '1qaz@WSX'
  fill_in "user[login]", :with => email unless find(:xpath, '//*[@id="user_login"]').value == email
  find('.interaction-click-control-sign-in').click
end

Then(/^.+ should see a form to enter information about employee, address and dependents details for (.*)$/) do |named_person|
  person = people[named_person]
  # Census Employee
  fill_in 'census_employee[first_name]', with: person[:first_name]
  fill_in 'census_employee[last_name]', with: person[:last_name]
  find(:xpath, "//p[contains(., 'NONE')]").click
  find(:xpath, "//li[contains(., 'Jr.')]").click

  fill_in 'jq_datepicker_ignore_census_employee[dob]', :with => person[:dob]
  fill_in 'census_employee[ssn]', :with => person[:ssn]

  find('label[for=census_employee_gender_male]').click

  fill_in 'jq_datepicker_ignore_census_employee[hired_on]', :with => (TimeKeeper.date_of_record - 30.days).strftime("%m/%d/%Y")
  find(:xpath, "//label[input[@name='census_employee[is_business_owner]']]").click

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

  fill_in 'census_employee[email_attributes][address]', :with => (@u.email :email)

  find('.form-inputs .add_fields').click

  # need to get name attribute since it's got a timestamp in it
  name = find(:xpath, "//div[@id='dependent_info']//input[@placeholder='FIRST NAME']")['name']
  fill_in name, :with => 'Mary'
  fill_in name.gsub('first', 'middle'), :with => 'K'
  fill_in name.gsub('first', 'last'), :with => 'Doe'
  fill_in name.gsub('first_name', 'ssn'), :with => '321321321'
  fill_in "jq_datepicker_ignore_#{name.gsub('first_name', 'dob')}", :with => '10/12/2012'

  find(:xpath, "//p[contains(text(), 'SELECT RELATIONSHIP')]").click
  find(:xpath, "//li[contains(text(), 'Child')]").click

  find(:xpath, "//label[@for='#{name.gsub('[', '_').gsub(']', '').gsub('first_name', 'gender_female')}']").click

  screenshot("create_census_employee_with_data")
  click_button "Create Employee"
end

And(/Employer should see employee (.*) created success message/) do |named_person|
  person = people[named_person]
  expect(find('.alert')).to have_content('successfully')
  expect(page).to have_content("#{person[:first_name]} #{person[:last_name]} Jr.")
  expect(page).to have_content("Employee Role Linked")
end

When(/^Individual (.*) logins to the Consumer Portal$/) do |named_person|
  person = people[named_person]
  visit "/"
  visit "/users/sign_in"
  fill_in "user[login]", :with => person[:email]
  find('#user_login').set(person[:email])
  fill_in "user[password]", :with => person[:password]
  fill_in "user[login]", :with => person[:email] unless find(:xpath, '//*[@id="user_login"]').value == person[:email]
  find('.interaction-click-control-sign-in').click
  visit "/insured/consumer_role/privacy?uqhp=true"
end

And(/I should see the employer congratulation message/) do
  expect(page).to have_content("Congratulations on your new job at")
end

When(/I click on the button of shop for plans/) do
  find(".interaction-click-control-shop-for-plans").click
end
