module GAWorld
  def general_agency(*traits)
    attributes = traits.extract_options!
    @general_agency ||= FactoryGirl.create :general_agency, *traits, attributes.merge(:general_agency_traits => :with_staff)
  end

  def user(*traits)
    attributes = traits.extract_options!
    @user ||= FactoryGirl.create :user, *traits, attributes
  end
end
World(GAWorld)

Given /^a general agency agent visits the DCHBX$/ do
  visit '/'
end

When /^they click the 'New General Agency' button$/ do
  click_link 'General Agency Registration'
end

Then /^they should see the new general agency form$/ do
  expect(page).to have_content('New General Agency')
  screenshot("general_agency_registration")
end

When /^they complete the new general agency form and hit the 'Submit' button$/ do
  fill_in 'organization[first_name]', with: Forgery(:name).first_name
  fill_in 'organization[last_name]', with: Forgery(:name).last_name
  fill_in 'jq_datepicker_ignore_organization[dob]', with: (Time.now - rand(20..50).years).strftime('%m/%d/%Y')
  find('.interaction-field-control-organization-email').click
  fill_in 'organization[email]', with: Forgery(:email).address
  fill_in 'organization[npn]', with: '2222222222'

  fill_in 'organization[legal_name]', with: (company_name = Forgery(:name).company_name)
  fill_in 'organization[dba]', with: company_name
  fill_in 'organization[fein]', with: '333333333'

  find(:xpath, "//p[contains(., 'Select Entity Kind')]").click
  find(:xpath, "//li[contains(., 'S Corporation')]").click

  find(:xpath, "//p[contains(., 'Select Practice Area')]").click
  find(:xpath, "//li[contains(., 'Both – Individual & Family AND Small Business Marketplaces')]").click

  find(:xpath, "//div[@class='language_multi_select']//p[@class='label']").click
  find(:xpath, "//li[contains(., 'English')]").click

  fill_in 'organization[office_locations_attributes][0][address_attributes][address_1]', with: Forgery(:address).street_address
  fill_in 'organization[office_locations_attributes][0][address_attributes][city]', with: 'Washington'

  find(:xpath, "//p[contains(., 'SELECT STATE')]").click
  find(:xpath, "//li[contains(., 'DC')]").click

  fill_in 'organization[office_locations_attributes][0][address_attributes][zip]', with: '20001'

  fill_in 'organization[office_locations_attributes][0][phone_attributes][area_code]', with: Forgery(:address).phone.match(/\((\d\d\d)\)/)[1]
  fill_in 'organization[office_locations_attributes][0][phone_attributes][number]', with: Forgery(:address).phone.match(/\)(.*)$/)[1]

  find('.interaction-click-control-create-general-agency').click
end

Then /^they should see a confirmation message$/ do
  expect(page).to have_content('Your registration has been submitted. A response will be sent to the email address you provided once your application is reviewed.')
end

Then /^a pending approval status$/ do
  expect(GeneralAgencyProfile.last.aasm_state).to eq('is_applicant')
end

Given /^an HBX admin exists$/ do
  user :with_family, :hbx_staff
end

And /^a general agency, pending approval, exists$/ do
  general_agency
  staff = general_agency.general_agency_profile.general_agency_staff_roles.order(id: :desc).first.general_agency_staff_roles.last
  staff.person.emails.last.update(kind: 'work')
end

When /^the HBX admin visits the general agency list$/ do
  login_as user, scope: :user
  visit exchanges_hbx_profiles_root_path
  click_link 'General Agencies'
end

Then /^they should see the pending general agency$/ do
  expect(page).to have_content(general_agency.legal_name)
  screenshot("general_agency_list")
end

When /^they click the link of general agency$/ do
  click_link general_agency.legal_name
end

Then /^they should see the home of general agency$/ do
  expect(page).to have_content("General Agency : #{general_agency.legal_name}")
  screenshot("general_agency_homepage")
end

When /^they visit the list of staff$/ do
  find('.interaction-click-control-staff').click
end

Then /^they should see the name of staff$/ do
  full_name = general_agency.general_agency_profile.general_agency_staff_roles.order(id: :desc).first.full_name
  expect(page).to have_content("General Agency Staff")
  expect(page).to have_content(general_agency.legal_name)
  expect(page).to have_content(full_name)
  screenshot("general_agency_staff_list")

  click_link full_name
end

When /^they approve the general agency$/ do
  click_link general_agency.general_agency_profile.general_agency_staff_roles.order(id: :desc).first.full_name
  screenshot("general_agency_staff_edit_page")
  click_button 'Approve'
end

Then /^they should see updated status$/ do
  expect(find('.alert')).to have_content('Staff approved successfully.')
  screenshot("general_agency_staff_approved")
end

Then /^the general agency should receive an email$/ do
  staff = general_agency.general_agency_profile.general_agency_staff_roles.order(id: :desc).first.general_agency_staff_roles.last
  open_email(staff.email_address)
end

Given /^a general agency, approved, awaiting account creation, exists$/ do
  general_agency
  staff = general_agency.general_agency_profile.general_agency_staff_roles.first.general_agency_staff_roles.last
  staff.person.emails.last.update(kind: 'work')
  staff.approve!
end

When /^the HBX admin visits the link received in the approval email$/ do
  staff = general_agency.general_agency_profile.general_agency_staff_roles.first.general_agency_staff_roles.last
  email_address = staff.email_address

  open_email(email_address)
  expect(current_email.to).to eq([email_address])

  invitation_link = links_in_email(current_email).first
  invitation_link.sub!(/http\:\/\/127\.0\.0\.1\:3000/, '')
  visit(invitation_link)
end

Then /^they should see an account creation form$/ do
  expect(page).to have_css('.interaction-click-control-create-account')
  screenshot("general_agency_staff_register_by_invitation")
end

When /^they complete the account creation form and hit the 'Submit' button$/ do
  email_address = general_agency.general_agency_profile.general_agency_staff_roles.first.emails.first.address
  fill_in "user[email]", with: email_address
  fill_in "user[password]", with: "aA1!aA1!aA1!"
  fill_in "user[password_confirmation]", with: "aA1!aA1!aA1!"
  click_button 'Create account'
end

Then /^they should see a welcome message$/ do
  expect(page).to have_content('Welcome to DC Health Link. Your account has been created.')
  screenshot("general_agency_homepage_for_staff")
end

Then /^they see the General Agency homepage$/ do
  expect(page).to have_content(general_agency.legal_name)
end

Given /^a general agency, approved, confirmed, exists$/ do
  general_agency(legal_name: 'Rooxo')
  staff = general_agency.general_agency_profile.general_agency_staff_roles.order(id: :desc).first.general_agency_staff_roles.last
  staff.person.emails.last.update(kind: 'work')
  email_address = general_agency.general_agency_profile.general_agency_staff_roles.first.emails.first.address
  user = FactoryGirl.create(:user, email: "ga1@dc.gov", password: "1qaz@WSX", password_confirmation: "1qaz@WSX")

  staff.person.user = user
  staff.person.save
  user.roles << "general_agency_staff" unless user.roles.include?("general_agency_staff")
  user.save
end

And /^a broker exists$/ do
  organization = FactoryGirl.create(:organization, legal_name: 'Acarehouse Inc', dba: 'Acarehouse')
  broker_agency = FactoryGirl.create(:broker_agency_profile, organization: organization)
  person = broker_agency.primary_broker_role.person
  person.emails.last.update(kind: 'work')
  user = FactoryGirl.create(:user, email: "broker1@dc.gov", password: "1qaz@WSX", password_confirmation: "1qaz@WSX")
  person.user = user
  person.broker_agency_staff_roles << ::BrokerAgencyStaffRole.new({broker_agency_profile: broker_agency, aasm_state: 'active'})
  person.save
  user.roles << "broker" unless user.roles.include?("broker")
  if !user.roles.include?("broker_agency_staff")
    user.roles << "broker_agency_staff"
  end
  user.save
  broker_role = person.broker_role
  broker_role.approve
  broker_role.broker_agency_accept
  broker_role.broker_agency_profile_id = broker_agency.id
  broker_role.save
  broker_agency.approve!
end

And /^an employer exists for ga$/ do
  organization = FactoryGirl.create(:organization, legal_name: 'EmployerA Inc', dba: 'EmployerA')
  employer_profile = FactoryGirl.create :employer_profile, organization: organization
  user = FactoryGirl.create :user, :with_family, :employer_staff, email: 'employer1@dc.gov', password: '1qaz@WSX', password_confirmation: '1qaz@WSX'
  FactoryGirl.create :employer_staff_role, person: user.person, employer_profile_id: employer_profile.id
end

When /^the employer login in$/ do
  visit '/'
  click_link 'Employer Portal'
  find('.interaction-click-control-sign-in-existing-account').click

  fill_in "user[email]", with: "employer1@dc.gov"
  find('#user_email').set("employer1@dc.gov")
  fill_in "user[password]", with: "1qaz@WSX"
  fill_in "user[email]", :with => "employer1@dc.gov" unless find(:xpath, '//*[@id="user_email"]').value == "employer1@dc.gov"
  find('.interaction-click-control-sign-in').click
end

Then /^the employer should see the home of employer$/ do
  expect(page).to have_content('Signed in successfully')
  expect(page).to have_content("I'm an Employer")
end

When /^the employer click the link of brokers$/ do
  find('.interaction-click-control-brokers').click
end

Then /^the employer should see the broker agency$/ do
  expect(page).to have_content('Acarehouse')
end

Then /^the employer should see broker active for the employer$/ do
  expect(page).to have_content('Acarehouse')
  expect(page).to have_content('Active Broker')
end

When /^the broker login in$/ do
  visit '/'
  click_link 'Broker Agency Portal'
  find('.interaction-click-control-sign-in-existing-account').click

  fill_in "user[email]", with: "broker1@dc.gov"
  find('#user_email').set("broker1@dc.gov")
  fill_in "user[password]", with: "1qaz@WSX"
  fill_in "user[email]", :with => "broker1@dc.gov" unless find(:xpath, '//*[@id="user_email"]').value == "broker1@dc.gov"
  find('.interaction-click-control-sign-in').click
end

Then /^the broker should see the home of broker$/ do
  expect(page).to have_content('Broker Agency : Acarehouse')
end

When /^the broker visits their Employers page$/ do
  find('.interaction-click-control-employers').click
end

And /^selects the general agency from dropdown for the employer$/ do
  expect(page).to have_content('EmployerA')
  find("input#employer_ids_").click
  find(:xpath, "//p[@class='label']").click
  find(:xpath, "//li[contains(., 'Rooxo')]").click
  find("input.btn-primary").click
end

Then /^the employer will be assigned that general agency$/ do
  expect(page).to have_content('Employers')
  expect(page).to have_content('EmployerA Inc')
  expect(page).to have_content('General Agencies')
  expect(page).to have_content('Rooxo')
end

When /^the broker click the link of clear assign$/ do
  click_link 'clear assign'
end

Then /^the employer will not be assigned that general agency$/ do
  expect(page).to have_content('Employers')
  expect(page).to have_content('EmployerA Inc')
  expect(page).to have_content('General Agencies')
  expect(page).not_to have_content('Rooxo')
end

When /^the broker visits their general agencies page$/ do
  find(".interaction-click-control-general-agencies").click
end

And /^the broker set default ga$/ do
  click_link 'Set Default GA'
end

When /^the ga login in$/ do
  email_address = "ga1@dc.gov"
  visit '/'
  click_link 'General Agency Portal'
  find('.interaction-click-control-sign-in-existing-account').click

  fill_in "user[email]", with: email_address
  find('#user_email').set(email_address)
  fill_in "user[password]", with: "1qaz@WSX"
  fill_in "user[email]", :with => email_address unless find(:xpath, '//*[@id="user_email"]').value == email_address
  find('.interaction-click-control-sign-in').click
end

Then /^the ga should see the home of ga$/ do
  expect(page).to have_content('General Agency : Rooxo')
end

When /^the ga visits their Employers page$/ do
  find('.interaction-click-control-employers').click
end

Then /^the ga should see the employer$/ do
  expect(page).to have_content('EmployerA Inc')
end

When /^the ga click the name of employer$/ do
  click_link "EmployerA Inc"
end

Then /^the ga should see the home of employer$/ do
  expect(page).to have_content('My Health Benefits Program')
end

Then /^the ga should see the broker$/ do
  expect(page).to have_content('Acarehouse')
  expect(page).to have_selector('.disabled', text: 'Change Broker')
  expect(page).to have_selector('.disabled', text: 'ROWSE BROKERS')
end

When /^the ga click the back link$/ do
  click_link "I'm a General Agency"
end
