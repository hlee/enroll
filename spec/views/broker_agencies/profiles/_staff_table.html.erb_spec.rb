require "rails_helper"

RSpec.describe "broker_agencies/profiles/show.html.erb" do
  let(:organization) { FactoryGirl.create(:organization) }
  let(:broker_agency_profile) { FactoryGirl.create(:broker_agency_profile, organization: organization) }
  let(:broker_role1) { FactoryGirl.create(:broker_role, broker_agency_profile_id: broker_agency_profile.id) }
  let(:broker_role2) { FactoryGirl.create(:broker_role, broker_agency_profile_id: broker_agency_profile.id)}
  let(:person1) {FactoryGirl.create(:person)}
  let(:person2) {FactoryGirl.create(:person)}
  before :each do
    allow(person1).to receive(:broker_role).and_return(broker_role1)
    allow(person2).to receive(:broker_role).and_return(broker_role2)
    assign :broker_agency_profile, broker_agency_profile
    assign :staff, [person1, person2]
    render template: "broker_agencies/profiles/_staff_table.html.erb"
  end

  it "should have title" do
    expect(rendered).to have_selector('.help_button', text: 'Help')
    expect(rendered).to have_selector('th', text: 'Organization')
  end
end
