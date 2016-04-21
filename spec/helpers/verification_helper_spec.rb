require "rails_helper"

RSpec.describe VerificationHelper, :type => :helper do

  describe "#doc_status_label" do
    doc_status_array = VlpDocument::VLP_DOCUMENTS_VERIF_STATUS
    doc_status_classes = ["warning", "default", "success", "danger"]
    doc_status_array.each_with_index do |doc_verif_status, index|
      context "doc status is #{doc_verif_status}" do
        let(:document) { FactoryGirl.build(:vlp_document, :status=>doc_verif_status) }
        it "returns #{doc_status_classes[index]} class for #{doc_verif_status} document status" do
          expect(helper.doc_status_label(document)).to eq doc_status_classes[index]
        end
      end
    end
  end

  describe "#verification_type_status" do
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    before :each do
      assign(:person, person)
    end
    context "SSN and Citizenship type" do
      it "returns outstanding status for consumer without state residency" do
        person.consumer_role.is_state_resident = false
        expect(helper.verification_type_status("Social Security Number", person)).to eq "outstanding"
      end

      it "returns verified status for consumer with state residency" do
        expect(helper.verification_type_status("Social Security Number", person)).to eq "verified"
      end
    end

    context "Immigration status" do
      context "lawful presence determination successful" do
        let(:lawful_presence_determination) { FactoryGirl.build(:lawful_presence_determination) }
        it "returns verified status for consumer with state residency" do
          person.consumer_role.lawful_presence_determination = lawful_presence_determination
          expect(helper.verification_type_status("Immigration status", person)).to eq "verified"
        end
      end
      context "lawful presence determination fails" do
        let(:lawful_presence_determination) { FactoryGirl.build(:lawful_presence_determination, aasm_state: "verification_pending") }
        it "returns outstanding status for consumer without successful verification responce" do
          person.consumer_role.lawful_presence_determination = lawful_presence_determination
          expect(helper.verification_type_status("Immigration status", person)).to eq "outstanding"
        end
      end
    end
  end

  describe "#verification_type_class" do
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    let(:lawful_presence_determination) { FactoryGirl.build(:lawful_presence_determination) }
    before :each do
      assign(:person, person)
    end
    context "verification type status verified" do
      it "returns success SSN verified" do
        expect(helper.verification_type_class("Social Security Number", person)).to eq("success")
      end

      it "returns success for Citizenship verified" do
        expect(helper.verification_type_class("Citizenship", person)).to eq("success")
      end

      it "returns success for Immigration status verified" do
        person.consumer_role.lawful_presence_determination = lawful_presence_determination
        expect(helper.verification_type_class("Immigration status", person)).to eq("success")
      end
    end

    context "verification type status outstanding" do
      let(:lawful_presence_determination) { FactoryGirl.build(:lawful_presence_determination, aasm_state: "verification_pending") }
      before :each do
        person.consumer_role.is_state_resident = false
      end
      it "returns danger outstanding SSN" do
        expect(helper.verification_type_class("SSN", person)).to eq("danger")
      end

      it "returns danger for outstanding Citizenship" do
        expect(helper.verification_type_class("Citizenship", person)).to eq("danger")
      end

      it "returns danger for outstanding Immigration status" do
        person.consumer_role.lawful_presence_determination = lawful_presence_determination
        expect(helper.verification_type_class("Immigration status", person)).to eq("danger")
      end
    end
  end

  describe "#unverified?" do
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    before :each do
      assign(:person, person)
    end
    it "returns true if person is not fully verified" do
      expect(helper.unverified?(person)).to eq true
    end

    it "returns false if person consumer role status is fully verified" do
      person.consumer_role.aasm_state = "fully_verified"
      expect(helper.unverified?(person)).to be_falsey
    end
  end

  describe "#enrollment_group_verified?" do
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    let(:family) { FactoryGirl.create(:family, :with_primary_family_member) }
    before :each do
      assign(:person, person)
    end
    it "returns true if all family members are fully verified" do
      family.family_members.each do |member|
        member.person = FactoryGirl.create(:person, :with_consumer_role)
        member.person.consumer_role.aasm_state="fully_verified"
        member.save
      end
      allow_any_instance_of(Person).to receive_message_chain("primary_family.active_family_members").and_return(family.family_members)
      expect(helper.enrollment_group_verified?(person)).to eq true
    end

    it "returns false if any of family members is not fully verified" do
      family.family_members.each do |member|
        member.person = FactoryGirl.create(:person, :with_consumer_role)
        member.save
      end
      allow_any_instance_of(Person).to receive_message_chain("primary_family.active_family_members").and_return(family.family_members)
      expect(helper.enrollment_group_verified?(person)).to eq false
    end
  end

  describe "#verification due date" do
    let(:family) { FactoryGirl.build(:family) }
    let(:hbx_enrollment) { HbxEnrollment.new(:updated_at => TimeKeeper.date_of_record) }
    before :each do
      assign(:family, family)
    end
    context "for special verification period" do
      it "returns special verification period" do
        allow_any_instance_of(Family).to receive_message_chain("active_household.hbx_enrollments.verification_needed").and_return([hbx_enrollment])
        expect(helper.verification_due_date(family)).to eq TimeKeeper.date_of_record + 95.days
      end
    end

    context "with no special verification period" do
      it "calls determine due date method" do
        expect((helper.verification_due_date(family)).to_s).to include TimeKeeper.date_of_record.strftime("%Y")
      end
    end
  end

  describe "#documents uploaded" do
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    let(:family) { FactoryGirl.create(:family, :with_primary_family_member) }
    before :each do
      assign(:person, person)
    end

    it "returns true if any family member has uploaded docs" do
      family.family_members.each do |member|
        member.person = FactoryGirl.create(:person, :with_consumer_role)
      end
      allow_any_instance_of(Person).to receive_message_chain("primary_family.active_family_members").and_return(family.family_members)
      expect(helper.documents_uploaded).to be_falsey
    end
  end

  describe "#documents count" do
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }

    before :each do
      assign(:person, person)
    end
    it "returns the number of uploaded documents" do
      person.consumer_role.vlp_documents<<FactoryGirl.build(:vlp_document)
      expect(helper.documents_count(person)).to eq 2
    end
    it "returns 0 for consumer without vlp" do
      person.consumer_role.vlp_documents = []
      expect(helper.documents_count(person)).to eq 0
    end
  end
end