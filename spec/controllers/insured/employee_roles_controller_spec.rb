require 'rails_helper'

RSpec.describe Insured::EmployeeRolesController, :dbclean => :after_each do
  describe "PUT update" do
    let(:employee_role_id) { "123455555" }
    let(:person_parameters) { { :first_name => "SOMDFINKETHING", :employee_role_id => employee_role_id} }
    let(:organization_id) { "1234324234" }
    let(:person_id) { "4324324234" }
    let(:benefit_group) { double }
    let(:census_employee) { double(:hired_on => "whatever" ) }
    let(:employer_profile) { double }
    let(:effective_date) { double }
    let(:person_id) { "5234234" }
    let(:employee_role) { double(:id => employee_role_id, :employer_profile => employer_profile, :benefit_group => benefit_group, :census_employee => census_employee) }
    let(:person) { Person.new }
    let(:user) {FactoryGirl.create(:user)}
    let(:role_form) {
      Forms::EmployeeRole.new(person, employee_role)
    }

    before(:each) do
      sign_in
      allow(Person).to receive(:find).with(person_id).and_return(person)
      allow(person).to receive(:employee_roles).and_return([employee_role])
      allow(Forms::EmployeeRole).to receive(:new).with(person, employee_role).and_return(role_form)
      allow(benefit_group).to receive(:effective_on_for).with("whatever").and_return(effective_date)
      allow(role_form).to receive(:update_attributes).with(person_parameters).and_return(save_result)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:employee_roles).and_return([employee_role])
      allow(employee_role).to receive(:save!).and_return(true)
      allow(employee_role).to receive(:bookmark_url=).and_return(true)
      sign_in user
      put :update, :person => person_parameters, :id => person_id
    end

    describe "given valid person parameters" do
      let(:save_result) { true }

      it "should redirect to dependent_details" do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(insured_family_members_path(:employee_role_id => employee_role_id))
      end
    end

    describe "given invalid person parameters" do
      let(:save_result) { false }

      it "should render edit" do
        expect(response).to have_http_status(:success)
        expect(response).to render_template("edit")
        expect(assigns(:person)).to eq role_form
      end
    end
  end

  describe "message to broker" do
    let(:user) { double("User", email: "test1@example.com") }
    let(:person) { double("Person", full_name: "test test") }
    let(:employee_role) { double("EmployeeRole") }
    let(:employer_profile) { double("EmployerProfile") }
    let(:broker_role) { double(
      "BrokerRole",
      email_address: "test@example.com"
      ) }
    let(:broker_agency_account) { double("BrokerAgencyAccount", writing_agent: broker_role) }
    let(:broker_agency_accounts) { [broker_agency_account] }
    let(:employee_roles) { [employee_role] }
    let(:family) { double("Family") }
    let(:household) { double("Household") }
    let(:hbx_enrollment) { double("HbxEnrollment", id: double("id"))}
    let(:hbx_enrollments) {double(:active => [hbx_enrollment])}
    before do
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:employee_roles).and_return(employee_roles)
      allow(employee_role).to receive(:employer_profile).and_return(employer_profile)
      allow(employer_profile).to receive(:broker_agency_accounts).and_return(broker_agency_accounts)
    end
    context "message to broker" do
      it "NEW, should intialize new message form" do
        allow(person).to receive(:primary_family).and_return(family)
        allow(family).to receive(:latest_household).and_return(household)
        allow(household).to receive(:hbx_enrollments).and_return(hbx_enrollments)
        sign_in user
        xhr :get, :new_message_to_broker
        expect(response).to have_http_status(:success)
        expect(response).to render_template("new_message_to_broker")
      end
      it "POST, send_message_to_broker" do
        allow(person).to receive(:user).and_return(user)
        allow(broker_role).to receive(:person).and_return(person)
        sign_in user
        post :send_message_to_broker, hbx_enrollment_id: hbx_enrollment.id
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(insured_plan_shopping_path(:id => hbx_enrollment.id))
      end
    end
  end

  describe "PUT update" do
    let(:user) { double("User") }
    let(:person) { double("Person") }
    let(:census_employee) { double("CensusEmployee") }
    let(:address) { double("Address") }
    let(:addresses) { [address] }
    let(:employee_role) { double("EmployeeRole", id: double("id"), :person => person) }
    let(:family) { double("Family") }
    let(:email){ double("Email", address: "test@example.com") }
    let(:id){ EmployeeRole.new.id }
    it "should render edit template" do
      allow(EmployeeRole).to receive(:find).and_return(employee_role)
      allow(user).to receive(:person).and_return(person)
      allow(Forms::EmployeeRole).to receive(:new).and_return(person)
      allow(employee_role).to receive(:new_census_employee).and_return(census_employee)
      allow(census_employee).to receive(:address).and_return(address)
      allow(person).to receive(:addresses).and_return(addresses)
      allow(person).to receive(:primary_family).and_return(family)
      allow(person).to receive(:emails).and_return([email])
      allow(census_employee).to receive(:email).and_return(email)
      allow(email).to receive(:address=).and_return("test@example.com")
      allow(controller).to receive(:build_nested_models).and_return(true)
      sign_in user
      get :edit, id: employee_role.id
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end
  end

  describe "POST create" do
    let(:person) { Person.new }
    let(:hired_on) { double }
    let(:family) { double }
    let(:benefit_group) { instance_double("BenefitGroup") }
    let(:employer_profile) { double }
    let(:census_employee) { instance_double("CensusEmployee", :hired_on => hired_on ) }
    let(:employee_role) { instance_double("EmployeeRole", :benefit_group => benefit_group, :new_census_employee => census_employee, :person => person, :id => "212342345") }
    let(:effective_date) { double }
    let(:employment_relationship) {
      instance_double("Forms::EmploymentRelationship", {
             :census_employee => census_employee
      } )
    }
    let(:employment_relationship_properties) { { :skllkjasdfjksd => "a3r123rvf" } }
    let(:user) { double(:idp_verified? => true) }

    context "can construct_employee_role" do
      before :each do
        allow(Forms::EmploymentRelationship).to receive(:new).with(employment_relationship_properties).and_return(employment_relationship)
        allow(Factories::EnrollmentFactory).to receive(:construct_employee_role).with(user, census_employee, employment_relationship).and_return([employee_role, family])
        allow(benefit_group).to receive(:effective_on_for).with(hired_on).and_return(effective_date)
        allow(census_employee).to receive(:employee_role_linked?).and_return(true)
        allow(employee_role).to receive(:census_employee).and_return(census_employee)
        sign_in(user)
        allow(user).to receive(:switch_to_idp!)
        post :create, :employment_relationship => employment_relationship_properties
      end

      it "should render the edit template" do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_insured_employee_path(:id => "212342345"))
      end

      it "should assign the employee_role" do
        expect(assigns(:employee_role)).to eq employee_role
      end

      it "should assign the person" do
        expect(assigns(:person)).to eq person
      end

      it "should assign the family" do
        expect(assigns(:family)).to eq family
      end
    end

    context "can not construct_employee_role" do
      before :each do
        allow(Forms::EmploymentRelationship).to receive(:new).with(employment_relationship_properties).and_return(employment_relationship)
        allow(Factories::EnrollmentFactory).to receive(:construct_employee_role).with(user, census_employee, employment_relationship).and_return([nil, nil])
        request.env["HTTP_REFERER"] = "/"
        sign_in(user)
        post :create, :employment_relationship => employment_relationship_properties
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
      end

      it "should get an alert" do
        expect(flash[:alert]).to match /You can not enroll as another employee/
      end
    end
  end

  describe "POST match" do
    let(:person_parameters) { { :first_name => "SOMDFINKETHING" } }
    let(:mock_employee_candidate) { instance_double("Forms::EmployeeCandidate", :valid? => validation_result, ssn: "333224444", dob: "08/15/1975") }
    let(:census_employee) { instance_double("CensusEmployee")}
    let(:hired_on) { double }
    let(:employment_relationships) { double }
    let(:user_id) { "SOMDFINKETHING_ID"}
    let(:user) { double("User",id: user_id ) }

    before(:each) do
      sign_in(user)
      allow(mock_employee_candidate).to receive(:match_census_employees).and_return(found_census_employees)
      allow(Forms::EmployeeCandidate).to receive(:new).with(person_parameters.merge({user_id: user_id})).and_return(mock_employee_candidate)
      allow(Factories::EmploymentRelationshipFactory).to receive(:build).with(mock_employee_candidate, census_employee).and_return(employment_relationships)
      post :match, :person => person_parameters
    end

    context "given invalid parameters" do
      let(:validation_result) { false }
      let(:found_census_employees) { [] }

      it "renders the 'search' template" do
        expect(response).to have_http_status(:success)
        expect(response).to render_template("search")
        expect(assigns[:employee_candidate]).to eq mock_employee_candidate
      end
    end

    context "given valid parameters" do
      let(:validation_result) { true }

      context "but with no found employee" do
        let(:found_census_employees) { [] }
        let(:person){ double("Person") }
        let(:consumer_role){ double("ConsumerRole", id: "test") }
        let(:person_parameters){{"dob"=>"1985-10-01", "first_name"=>"martin","gender"=>"male","last_name"=>"york","middle_name"=>"","name_sfx"=>"","ssn"=>"000000111"}}

        it "renders the 'no_match' template" do
          expect(response).to have_http_status(:success)
          expect(response).to render_template("no_match")
          expect(assigns[:employee_candidate]).to eq mock_employee_candidate
        end

        context "that find a matching employee" do
          let(:found_census_employees) { [census_employee] }

          it "renders the 'match' template" do
            expect(response).to have_http_status(:success)
            expect(response).to render_template("match")
            expect(assigns[:employee_candidate]).to eq mock_employee_candidate
            expect(assigns[:employment_relationships]).to eq employment_relationships
          end
        end
      end
    end
  end

  describe "GET search" do
    let(:user) { FactoryGirl.build(:user) }
    let(:person) { FactoryGirl.build(:person) }

    before(:each) do
      allow(user).to receive(:has_employee_role?).and_return(false)
      allow(user).to receive(:has_consumer_role?).and_return(false)
      allow(user).to receive(:person).and_return(person)
      sign_in(user)
      get :search
    end

    it "renders the 'search' template" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template("search")
      expect(assigns[:person]).to be_a(Forms::EmployeeCandidate)
    end

    it "saves last portal as employee search index" do
      expect(user.last_portal_visited).to eq search_insured_employee_index_path
    end
  end

  describe "GET welcome" do
    let(:user) { double("user") }
    let(:person) { double("person")}
    let(:employee_role) {FactoryGirl.create(:employee_role)}

    it "renders the 'welcome' template when user has no employee role" do
      allow(user).to receive(:has_employee_role?).and_return(false)
      allow(user).to receive(:has_consumer_role?).and_return(false)
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:last_portal_visited=).and_return(true)
      allow(user).to receive(:save!).and_return(true)
      sign_in(user)
      allow(user).to receive(:person).and_return(person)
      get :welcome
      expect(response).to have_http_status(:success)
      expect(response).to render_template("welcome")
    end

    it "renders the 'my account' template when user has employee role" do
      allow(user).to receive(:has_employee_role?).and_return(true)
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:last_portal_visited=).and_return(family_account_path)

      allow(user).to receive(:save!).and_return(true)
      allow(person).to receive(:employee_roles).and_return([employee_role])
      allow(employee_role).to receive(:bookmark_url).and_return(family_account_path)
      sign_in(user)
      get :welcome
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(family_account_path)
    end

  end
end
