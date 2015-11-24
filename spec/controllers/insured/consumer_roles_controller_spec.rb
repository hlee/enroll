require 'rails_helper'

RSpec.describe Insured::ConsumerRolesController, :type => :controller do
  let(:user){ FactoryGirl.create(:user, :consumer) }
  let(:person){ FactoryGirl.build(:person) }
  let(:family){ double("Family") }
  let(:family_member){ double("FamilyMember") }
  let(:consumer_role){ FactoryGirl.build(:consumer_role) }
  let(:bookmark_url) {'localhost:3000'}

  context "GET privacy" do
    before(:each) do
      sign_in user
      allow(user).to receive(:person).and_return(person)
    end
    it "should redirect" do
      allow(person).to receive(:consumer_role?).and_return(true)
      allow(person).to receive(:consumer_role).and_return(consumer_role)
      allow(consumer_role).to receive(:bookmark_url).and_return("test")
      get :privacy
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(person.consumer_role.bookmark_url)
    end
    it "should render privacy" do
      allow(person).to receive(:consumer_role?).and_return(false)
      get :privacy
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:privacy)
    end
  end

  describe "Get search" do
    let(:mock_employee_candidate) { instance_double("Forms::EmployeeCandidate", ssn: "333224444", dob: "08/15/1975") }

    before(:each) do
      sign_in user
      allow(Forms::EmployeeCandidate).to receive(:new).and_return(mock_employee_candidate)
      allow(user).to receive(:last_portal_visited=)
      allow(user).to receive(:save!).and_return(true)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:consumer_role).and_return(consumer_role)
      allow(person).to receive(:has_active_consumer_role?).and_return(false)
      allow(consumer_role).to receive(:save!).and_return(true)
    end

    it "should render search template" do
      get :search
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:search)
    end

    it "should set the session flag for aqhp the param exists" do
      get :search, aqhp: true
      expect(session[:individual_assistance_path]).to be_truthy
    end

    it "should unset the session flag for aqhp if the param does not exist upon return" do
      get :search, aqhp: true
      expect(session[:individual_assistance_path]).to be_truthy
      get :search, uqhp: true
      expect(session[:individual_assistance_path]).to be_falsey
    end

  end

  describe "POST match" do
    let(:person_parameters) { { :first_name => "SOMDFINKETHING" } }
    let(:mock_consumer_candidate) { instance_double("Forms::ConsumerCandidate", :valid? => validation_result, ssn: "333224444", dob: Date.new(1975, 8, 15), :first_name => "fname", :last_name => "lname") }
    let(:mock_employee_candidate) { instance_double("Forms::EmployeeCandidate", :valid? => validation_result, ssn: "333224444", dob: Date.new(1975, 8, 15), :first_name => "fname", :last_name => "lname", :match_census_employees => []) }
    let(:found_person){ [] }
    let(:person){ instance_double("Person") }

    before(:each) do
      allow(user).to receive(:idp_verified?).and_return false
      sign_in(user)
      allow(mock_consumer_candidate).to receive(:match_person).and_return(found_person)
      allow(Forms::ConsumerCandidate).to receive(:new).with(person_parameters.merge({user_id: user.id})).and_return(mock_consumer_candidate)
      allow(Forms::EmployeeCandidate).to receive(:new).and_return(mock_employee_candidate)
      allow(mock_employee_candidate).to receive(:valid?).and_return(false)
    end

    context "given invalid parameters" do
      let(:validation_result) { false }
      let(:found_person) { [] }

      it "renders the 'search' template" do
        post :match, :person => person_parameters
        expect(response).to have_http_status(:success)
        expect(response).to render_template("search")
        expect(assigns[:consumer_candidate]).to eq mock_consumer_candidate
      end
    end

    context "given valid parameters" do
      let(:validation_result) { true }

      context "but with no found employee" do
        let(:found_person) { [] }
        let(:person){ double("Person") }
        let(:person_parameters){{"dob"=>"1985-10-01", "first_name"=>"martin","gender"=>"male","last_name"=>"york","middle_name"=>"","name_sfx"=>"","ssn"=>"000000111"}}
        before :each do 
          post :match, :person => person_parameters
        end

        it "renders the 'no_match' template" do
          expect(response).to have_http_status(:success)
          expect(response).to render_template("no_match")
          expect(assigns[:consumer_candidate]).to eq mock_consumer_candidate
        end

        context "that find a matching employee" do
          let(:found_person) { [person] }

          it "renders the 'match' template" do
            expect(response).to have_http_status(:success)
            expect(response).to render_template("match")
            expect(assigns[:consumer_candidate]).to eq mock_consumer_candidate
          end
        end
      end

      context "when match employer" do 
        before :each do 
          allow(mock_consumer_candidate).to receive(:valid?).and_return(true)
          allow(mock_employee_candidate).to receive(:valid?).and_return(true)
          allow(mock_employee_candidate).to receive(:match_census_employees).and_return([])
          allow(Factories::EmploymentRelationshipFactory).to receive(:build).and_return(true)
          post :match, :person => person_parameters
        end

        it "render employee role match tempalte" do 
          expect(response).to have_http_status(:success)
          expect(response).to render_template('insured/employee_roles/match')
          expect(assigns[:employee_candidate]).to eq mock_employee_candidate
        end
      end
    end
  end
  context "POST create" do
    let(:person_params){{"dob"=>"1985-10-01", "first_name"=>"martin","gender"=>"male","last_name"=>"york","middle_name"=>"","name_sfx"=>"","ssn"=>"000000111","user_id"=>"xyz"}}
    before(:each) do
      allow(Factories::EnrollmentFactory).to receive(:construct_employee_role).and_return(consumer_role)
      allow(consumer_role).to receive(:person).and_return(person)
    end
    it "should create new person/consumer role object" do
      sign_in user
      post :create, person: person_params
      expect(response).to have_http_status(:redirect)
    end
  end
  context "POST create with failed construct_employee_role" do
    let(:person_params){{"dob"=>"1985-10-01", "first_name"=>"martin","gender"=>"male","last_name"=>"york","middle_name"=>"","name_sfx"=>"","ssn"=>"000000111","user_id"=>"xyz"}}
    before(:each) do
      allow(Factories::EnrollmentFactory).to receive(:construct_consumer_role).and_return(nil)
    end
    it "should throw a 500 error" do
      sign_in user
      post :create, person: person_params
      expect(response).to have_http_status(500)
    end
  end

  context "GET edit" do
    before(:each) do
      allow(ConsumerRole).to receive(:find).and_return(consumer_role)
      allow(consumer_role).to receive(:person).and_return(person)
      allow(consumer_role).to receive(:build_nested_models_for_person).and_return(true)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:consumer_role).and_return(consumer_role)
      allow(consumer_role).to receive(:save!).and_return(true)
      allow(consumer_role).to receive(:bookmark_url=).and_return(true)
    end
    it "should render new template" do
      sign_in user
      get :edit, id: "test"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end
  end

  describe "GET immigration_document_options" do

    it "render javascript template" do
      sign_in
      xhr :get, :immigration_document_options, format: :js
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:immigration_document_options)
    end

    context "when object type Person" do
      let(:person_params){{"dob"=>"1985-10-01", "first_name"=>"martin","gender"=>"male","last_name"=>"york","middle_name"=>"","name_sfx"=>"","ssn"=>"000000111","user_id"=>"xyz"}}
      before(:each) do
        allow(Factories::EnrollmentFactory).to receive(:construct_employee_role).and_return(consumer_role)
        allow(consumer_role).to receive(:person).and_return(person)
      end
      it "object has correct class" do
        post :create, person: person_params
        type = person.class.to_s
        expect(type).to eq("Person")
      end
    end
  end

  context "PUT update" do
    let(:person_params){{"dob"=>"1985-10-01", "first_name"=>"martin","gender"=>"male","last_name"=>"york","middle_name"=>"","name_sfx"=>"","ssn"=>"468389102","user_id"=>"xyz", us_citizen:"true", naturalized_citizen: "true"}}
    let(:person){ FactoryGirl.build(:person) }

    before(:each) do
      allow(ConsumerRole).to receive(:find).and_return(consumer_role)
      allow(consumer_role).to receive(:build_nested_models_for_person).and_return(true)
      allow(consumer_role).to receive(:person).and_return(person)
      allow(user).to receive(:person).and_return person
      allow(person).to receive(:consumer_role).and_return consumer_role
      sign_in user
    end

    it "should update existing person" do
      allow(consumer_role).to receive(:update_by_person).and_return(true)
      allow(controller).to receive(:update_vlp_documents).and_return(true)
      put :update, person: person_params, id: "test"
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(ridp_agreement_insured_consumer_role_index_path)
    end

    it "should not update the person" do
      allow(controller).to receive(:update_vlp_documents).and_return(false)
      allow(consumer_role).to receive(:update_by_person).and_return(true)
      put :update, person: person_params, id: "test"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it "should not update the person" do
      allow(controller).to receive(:update_vlp_documents).and_return(false)
      allow(consumer_role).to receive(:update_by_person).and_return(false)
      put :update, person: person_params, id: "test"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it "should raise error" do
      put :update, person: person_params, id: "test"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
      expect(person.errors.full_messages).to include "Document type cannot be blank"
    end
  end

  context "GET immigration_document_options" do
    let(:family_member) {FamilyMember.new}
    before :each do
      sign_in user
    end

    it "should get person" do
      allow(Person).to receive(:find).and_return person
      xhr :get, 'immigration_document_options', {target_type: 'Person', target_id: "person_id", vlp_doc_target: "vlp doc", format: :js}
      expect(response).to have_http_status(:success)
      expect(assigns(:target)).to eq person
      expect(assigns(:vlp_doc_target)).to eq "vlp doc"
    end

    it "should get FamilyMember" do
      allow(Forms::FamilyMember).to receive(:find).and_return family_member
      xhr :get, 'immigration_document_options', {target_type: 'Forms::FamilyMember', target_id: "id", vlp_doc_target: "vlp doc", format: :js}
      expect(response).to have_http_status(:success)
      expect(assigns(:target)).to eq family_member
      expect(assigns(:vlp_doc_target)).to eq "vlp doc"
    end

    it "should get FamilyMember" do
      xhr :get, 'immigration_document_options', {target_type: 'Forms::FamilyMember', vlp_doc_target: "vlp doc", format: :js}
      expect(response).to have_http_status(:success)
      expect(assigns(:target).class).to eq Forms::FamilyMember
      expect(assigns(:vlp_doc_target)).to eq "vlp doc"
    end
  end
end
