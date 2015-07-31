require "rails_helper"

RSpec.describe "group_selection/_enrollment_eligibility_reasons.html.erb" do
    let(:person) { FactoryGirl.create(:person) }
    let(:employee_role) { FactoryGirl.create(:employee_role) }
    let(:family) {double(current_enrollment_eligibility_reasons: [])}

    before(:each) do
      assign(:family, family)
      assign(:person, person)
      assign(:employee_role, employee_role)
      #allow(family_member3).to receive(:is_primary_applicant?).and_return(false)

      controller.request.path_parameters[:person_id] = person.id
      controller.request.path_parameters[:employee_role_id] = employee_role.id
      render "enrollment_eligibility_reasons"
    end

    it "should show the title" do
      expect(rendered).to match /Eligibility Enrollment Reasons/
    end
end
