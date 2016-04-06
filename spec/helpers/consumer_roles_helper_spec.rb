require "rails_helper"

RSpec.describe ConsumerRolesHelper, :type => :helper do
  let(:person) {FactoryGirl.build(:person)}
  let(:consumer_role) {FactoryGirl.build(:consumer_role)}
  before :each do
    allow(person).to receive(:consumer_role).and_return consumer_role
    allow(consumer_role).to receive(:person).and_return person
  end

  context "find_consumer_role_for_fields" do
    it "should return consumer_role from person" do
      expect(helper.find_consumer_role_for_fields(person)).to eq consumer_role
    end

    context "dependent" do
      let(:dependent) {double}
      it "should return new consumer_role" do
        allow(dependent).to receive(:persisted?).and_return false
        expect(helper.find_consumer_role_for_fields(dependent).new_record?).to eq true
      end

      it "should return consumer_role from family_member" do
        allow(dependent).to receive(:family_member).and_return double(person: person)
        allow(dependent).to receive(:persisted?).and_return true
        expect(helper.find_consumer_role_for_fields(dependent)).to eq consumer_role
      end
    end
  end

  context "#show_naturalized_citizen_container" do
    it "should return true" do
      person.us_citizen = true
      expect(helper.show_naturalized_citizen_container(person)).to eq true
    end

    it "should return false" do
      person.us_citizen = false
      expect(helper.show_naturalized_citizen_container(person)).to eq false
    end

    it "should return false" do
      person.us_citizen = nil
      expect(helper.show_naturalized_citizen_container(person)).to eq false
    end
  end

  context "#show_immigration_status_container" do
    it "should return true" do
      person.us_citizen = false
      expect(helper.show_immigration_status_container(person)).to eq true
    end

    it "should return false" do
      person.us_citizen = true
      expect(helper.show_immigration_status_container(person)).to eq false
    end
  end

  context "#show_tribal_container" do
    it "should return true" do
      person.indian_tribe_member = true
      expect(helper.show_tribal_container(person)).to eq true
    end

    it "should return false" do
      person.indian_tribe_member = false
      expect(helper.show_tribal_container(person)).to eq false
    end

    it "should return false" do
      person.indian_tribe_member = nil
      expect(helper.show_tribal_container(person)).to eq false
    end
  end

  context "#show_naturalization_doc_type" do
    it "should return true" do
      person.us_citizen = true
      person.naturalized_citizen = true
      expect(helper.show_naturalization_doc_type(person)).to eq true
    end

    it "should return false" do
      person.us_citizen = false
      person.naturalized_citizen = true
      expect(helper.show_naturalization_doc_type(person)).to eq false
    end

    it "should return false" do
      person.us_citizen = true
      person.naturalized_citizen = false
      expect(helper.show_naturalization_doc_type(person)).to eq false
    end
  end

  context "#show_immigration_doc_type" do
    it "should return true" do
      person.us_citizen = false
      person.eligible_immigration_status = true
      expect(helper.show_immigration_doc_type(person)).to eq true
    end

    it "should return false" do
      person.us_citizen = true
      person.eligible_immigration_status = true
      expect(helper.show_immigration_doc_type(person)).to eq false
    end

    it "should return false" do
      person.us_citizen = false
      person.eligible_immigration_status = false
      expect(helper.show_immigration_doc_type(person)).to eq false
    end
  end

  context "show_vlp_documents_container" do
    it "should return true" do
      allow(helper).to receive(:show_naturalization_doc_type).and_return true
      allow(helper).to receive(:show_immigration_doc_type).and_return false
      expect(helper.show_vlp_documents_container(person)).to eq true
    end

    it "should return true" do
      allow(helper).to receive(:show_naturalization_doc_type).and_return false
      allow(helper).to receive(:show_immigration_doc_type).and_return true
      expect(helper.show_vlp_documents_container(person)).to eq true
    end

    it "should return false" do
      allow(helper).to receive(:show_naturalization_doc_type).and_return false
      allow(helper).to receive(:show_immigration_doc_type).and_return false
      expect(helper.show_vlp_documents_container(person)).to eq false
    end
  end

  context "show_keep_existing_plan" do
    let(:date) { TimeKeeper.date_of_record }
    let(:hbx_enrollment) {double(effective_on: date)}

    it "should return false with shop_for_plans" do
      expect(helper.show_keep_existing_plan("shop_for_plans", hbx_enrollment, date)).to eq false
    end

    context "without shop_for_plans" do
      it "hbx_enrollment and new_effective_on is in the same year" do
        expect(helper.show_keep_existing_plan("", hbx_enrollment, date)).to eq true
      end

      it "hbx_enrollment and new_effective_on is not in the same year" do
        expect(helper.show_keep_existing_plan("", hbx_enrollment, (date + 1.year))).to eq false
      end
    end
  end

  context "show_consumer_role_state" do
    let(:consumer_role) {FactoryGirl.build(:consumer_role)}

    it "should return blank when consumer_role is nil" do
      expect(helper.show_consumer_role_state(nil)).to eq ""
    end

    it "should return Pending when consumer_role is verifications_pending" do
      allow(consumer_role).to receive(:aasm_state).and_return "verifications_pending"
      expect(helper.show_consumer_role_state(consumer_role)).to eq "Pending"
    end

    it "should return Verified when consumer_role is Verified" do
      allow(consumer_role).to receive(:aasm_state).and_return "fully_verified"
      expect(helper.show_consumer_role_state(consumer_role)).to eq "Verified"
    end

    it "should return Outstanding verifications when consumer_role is verification_outstanding" do
      allow(consumer_role).to receive(:aasm_state).and_return "verification_outstanding"
      expect(helper.show_consumer_role_state(consumer_role)).to eq "Outstanding verification"
    end
  end

  context "required_for_consumer_address" do
    it "should return false when required is blank" do
      expect(helper.required_for_consumer_address("", true)).to eq false
    end

    context "when required is not blank" do
      it "should return true when has_dc_adress is true" do
        expect(helper.required_for_consumer_address("address_required", true)).to eq true
      end
      it "should return false when has_dc_adress is false" do
        expect(helper.required_for_consumer_address("address_required", false)).to eq false
      end
    end
  end
end
