require 'rails_helper'

describe "shared/_comparison.html.erb" do

  random_value = rand(999_999_999)
  let(:mock_person){ instance_double("Person",full_name: "John Doe:#{random_value}", age_on: 21, dob: double("dob"))}
  let(:mock_member){ instance_double("HbxEnrollmentMember",primary_relationship: "self:#{random_value}", person: mock_person)}
  let(:mock_organization){ instance_double("Oganization", hbx_id: "3241251524", legal_name: "ACME Agency", dba: "Acme", fein: "034267010")}
  let(:mock_carrier_profile) { instance_double("CarrierProfile", :dba => "a carrier name", :legal_name => "name", :organization => mock_organization) }
  let(:mock_hbx_enrollment) { instance_double("HbxEnrollment", :hbx_enrollment_members => [mock_member, mock_member], :id => "3241251524", plan: mock_plan) }
  let(:mock_plan) { double("Plan",
      :name => "A Plan Name",
      :carrier_profile_id => "a carrier profile id",
      :carrier_profile => mock_carrier_profile,
      :metal_level => "Silver",
      :plan_type => "A plan type",
      :nationwide => true,
      :deductible => 0,
      :total_premium => 100,
      :total_employer_contribution => 20,
      :total_employee_cost => 30,
      :id => "1234234234",
      :sbc_document => Document.new({title: 'sbc_file_name', subject: "SBC",
                      :identifier=>'urn:openhbx:terms:v1:file_storage:s3:bucket:dchbx-enroll-sbc-local#7816ce0f-a138-42d5-89c5-25c5a3408b82'})
      ) }
  let(:mock_qhp){instance_double("Products::Qhp", :qhp_benefits => [], :plan => mock_plan, :plan_marketing_name=> "A Plan Name")}
  let(:mock_qhps) {[mock_qhp]}
  let(:sbc_document) { double("SbcDocument", identifier: "download#abc") }
  let(:mock_family){ double("Family") }

  before :each do
    Caches::MongoidCache.release(CarrierProfile)
    allow(mock_plan).to receive(:sbc_document).and_return(mock_plan.sbc_document)
    allow(mock_qhp).to receive("[]").with(:total_employee_cost).and_return(30)
    allow(mock_hbx_enrollment).to receive(:humanized_dependent_summary).and_return(2)
    allow(mock_person).to receive(:primary_family).and_return(mock_family)
    allow(mock_family).to receive(:enrolled_hbx_enrollments).and_return([mock_hbx_enrollment])
    assign(:visit_types, [])
    assign :plan, mock_plan
    assign :person, mock_person
    assign :plans, [mock_plan]
    assign :hbx_enrollment, mock_hbx_enrollment
    render "shared/comparison", :qhps => mock_qhps
  end

  it "should have a link to open the sbc pdf" do
    expect(rendered).to have_selector("a[href='#{root_path + "document/download/dchbx-enroll-sbc-local/7816ce0f-a138-42d5-89c5-25c5a3408b82?content_type=application/pdf&filename=APlanName.pdf&disposition=inline"}']")
  end

  it "should contain some readable text" do
    ["$30.00", "Nationwide", "A Plan Name", "A PLAN TYPE"].each do |t|
      expect(rendered).to have_content(t)
    end
  end

  it "should have print area" do
    expect(rendered).to have_selector('div#printArea')
  end

  it "should not have plan details text" do
    expect(rendered).not_to match(/Plan Details/)
  end

  it "should have download link" do
    expect(rendered).to have_selector('a', text: 'Download')
  end

  it "should not have Out of Network text" do
    expect(rendered).to_not have_selector('th', text: 'Out of Network')
  end

  it "should have coinsurance text" do
    expect(rendered).to have_selector('th', text: 'COINSURANCE')
  end

  it "should have copay text" do
    expect(rendered).to have_selector('th', text: 'CO-PAY')
  end

  it "should have plan data" do
    expect(rendered).to match(/#{mock_plan.name}/)
  end

  it "should have print link" do
    expect(rendered).to have_selector('button', text: 'Print')
  end

  it "should have title and other text" do
    expect(rendered).to have_selector('h1', text: /Choose Plan - Compare Selected Plans/ )
    expect(rendered).to have_selector('h4', text: /Each plan is different. Make sure you understand the differences so you can find the right plan to meet your needs and budget./ )
    expect(rendered).to have_selector('h4', text: /Please review SBC for any coinsurance costs./ )
  end
end
