require 'rails_helper'

RSpec.describe User, :type => :model do

  let(:gen_pass) { User.generate_valid_password }

  let(:valid_params) do
    {
      email: "test@test.com",
      password: gen_pass,
      password_confirmation: gen_pass,
      approved: true,
      person: {first_name: "john", last_name: "doe", ssn: "123456789"}
    }
  end

  describe 'user' do

    context 'when email' do
      let(:params){valid_params.deep_merge!({email: "test"})}
      it 'is invalid' do
        expect(User.create(**params).errors[:email].any?).to be_truthy
        expect(User.create(**params).errors[:email]).to eq ["is invalid"]
      end
    end

    context 'when email' do
      let(:params){valid_params.deep_merge!({email: ""})}
      it 'is empty' do
        expect(User.create(**params).errors[:email].any?).to be_truthy
        expect(User.create(**params).errors[:email]).to eq ["can't be blank"]
      end
    end

    context 'when password' do
      let(:params){valid_params.deep_merge!({password: ""})}
      it 'is empty' do
        expect(User.create(**params).errors[:password].any?).to be_truthy
        expect(User.create(**params).errors[:password]).to eq ["can't be blank"]
        expect(User.create(**params).errors[:password_confirmation]).to eq ["doesn't match Password"]
      end
    end

    context 'when password' do
      let(:params){valid_params.deep_merge!({password: valid_params[:email] + "aA1!"})}
      it 'contains username' do
        expect(User.create(**params).errors[:password].any?).to be_truthy
        expect(User.create(**params).errors[:password]).to eq ["password cannot contain username"]
      end
    end

    context 'when password' do
      let(:params){valid_params.deep_merge!({password: "1234566746464DDss"})}
      it 'does not contain valid complexity' do
        expect(User.create(**params).errors[:password].any?).to be_truthy
        expect(User.create(**params).errors[:password]).to eq ["must include at least one lowercase letter, one uppercase letter, one digit, and one character that is not a digit or letter"]
      end
    end

    context 'when password' do
      let(:params){valid_params.deep_merge!({password: "12_-66746464DDDss"})}
      it 'repeats a consecutive character more than once' do
        expect(User.create(**params).errors[:password].any?).to be_truthy
        expect(User.create(**params).errors[:password]).to eq ["must not repeat consecutive characters more than once"]
      end
    end

    context 'when password & password confirmation' do
      let(:params){valid_params.deep_merge!({password: "1Aa@"})}
      it 'does not match' do
        expect(User.create(**params).errors[:password].any?).to be_truthy
        expect(User.create(**params).errors[:password_confirmation].any?).to be_truthy
        expect(User.create(**params).errors[:password]).to eq ["is too short (minimum is 8 characters)"]
        expect(User.create(**params).errors[:password_confirmation]).to eq ["doesn't match Password"]
      end
    end

    context 'when associated person' do
      let(:params){valid_params}
      it 'first name is invalid' do
        params[:person][:first_name] = ""
        expect(User.create(**params).errors[:person].any?).to be_truthy
        expect(User.create(**params).errors[:person]).to eq ["is invalid"]
        expect(User.create(**params).person.errors[:first_name].any?).to be_truthy
        expect(User.create(**params).person.errors[:first_name]).to eq ["can't be blank"]
      end

      it 'last name is invalid' do
        params[:person][:last_name] = ""
        expect(User.create(**params).errors[:person].any?).to be_truthy
        expect(User.create(**params).errors[:person]).to eq ["is invalid"]
        expect(User.create(**params).person.errors[:last_name].any?).to be_truthy
        expect(User.create(**params).person.errors[:last_name]).to eq ["can't be blank"]
      end

      it 'ssn is invalid' do
        params[:person][:ssn] = "123"
        expect(User.create(**params).errors[:person].any?).to be_truthy
        expect(User.create(**params).errors[:person]).to eq ["is invalid"]
        expect(User.create(**params).person.errors[:ssn].any?).to be_truthy
        expect(User.create(**params).person.errors[:ssn]).to eq ["SSN must be 9 digits"]
      end
    end

    context "when all params are valid" do
      let(:params){valid_params}
      it "should not have errors on create" do
        record = User.create(**params)
        expect(record).to be_truthy
        expect(record.errors.messages.size).to eq 0
      end
    end

    context "roles" do
      let(:params){valid_params.deep_merge({roles: ["employee", "employer_staff", "broker", "hbx_staff"]})}
      it "should return proper roles" do
        user = User.new(**params)
        expect(user.has_employee_role?).to be_truthy
        expect(user.has_employer_staff_role?).to be_truthy
        expect(user.has_broker_role?).to be_truthy
        expect(user.has_hbx_staff_role?).to be_truthy
      end
    end

    context "should instantiate person" do
      let(:params){valid_params}
      it "should build person" do
        user = User.new(**params)
        user.instantiate_person
        expect(user.person).to be_an_instance_of Person
      end
    end
  end
end

describe User do
  subject { User.new(:identity_final_decision_code => decision_code_value) }

  describe "with no identity final decision code" do
    let(:decision_code_value) { nil }
    it "should not be considered identity_verified" do
      expect(subject.identity_verified?).to eq false
    end
  end

  describe "with a non-successful final decision code" do
    let(:decision_code_value) { "lkdsjfaoifudjfnnkadjlkfajlafkl;f" }
    it "should not be considered identity_verified" do
      expect(subject.identity_verified?).to eq false
    end
  end

  describe "with a successful decision code" do
    let(:decision_code_value) { User::INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE }
    it "should be considered identity_verified" do
      expect(subject.identity_verified?).to eq true
    end
  end
end
