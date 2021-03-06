require 'rails_helper'

RSpec.describe "insured/plan_shoppings/_plan_details.html.erb" do
  let(:carrier_profile) { instance_double("CarrierProfile", id: "carrier profile id", legal_name: "legal_name") }
  let(:plan) do
    double(plan_type: "ppo", metal_level: "bronze", is_standard_plan: true,
      nationwide: "true", total_employee_cost: 100, deductible: 500,
      name: "My Plan", id: "my id", carrier_profile: nil,
      hios_id: "hios id", carrier_profile_id: carrier_profile.id,
      active_year: TimeKeeper.date_of_record.year, total_premium: 300,
      total_employer_contribution: 200,
      ehb: 0.9881,
      sbc_document: Document.new({title: 'sbc_file_name', subject: "SBC",
                                    :identifier=>'urn:openhbx:terms:v1:file_storage:s3:bucket:dchbx-sbc#7816ce0f-a138-42d5-89c5-25c5a3408b82'})
    )
  end
  let(:plan_hsa_status) { Hash.new }
  let(:hbx_enrollment_members) do
    []
  end
  let(:hbx_enrollment) do
    instance_double(
      "HbxEnrollment", id: "hbx enrollment id",
      hbx_enrollment_members: hbx_enrollment_members,
      plan: plan
    )
  end

  context "without aptc" do
    before :each do
      allow(Caches::MongoidCache).to receive(:lookup).with(CarrierProfile, anything).and_return(carrier_profile)
      assign(:plan_hsa_status, plan_hsa_status)
      assign(:hbx_enrollment, hbx_enrollment)
      assign(:enrolled_hbx_enrollment_plan_ids, [plan.id])
      assign(:carrier_names_map, {})
      allow(plan).to receive(:total_employee_cost).and_return 100
      allow(plan).to receive(:is_csr?).and_return false
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should display the main menu" do
      expect(rendered).not_to have_selector('a', text: /Waive/)
    end

    it "should display plan details" do
      expect(rendered).to match(/#{plan.name}/)
      expect(rendered).to match(/#{plan.carrier_profile}/)
      expect(rendered).to match(/#{plan.active_year}/)
      expect(rendered).to match(/#{plan.deductible}/)
      expect(rendered).to match(/#{plan.is_standard_plan}/)
      expect(rendered).to match(/#{plan.nationwide}/)
      expect(rendered).to match(/#{plan.total_employee_cost}/)
      expect(rendered).to match(/#{plan.plan_type}/)
      expect(rendered).to match(/#{plan.metal_level}/)
      expect(rendered).to match(/#{plan.hios_id}/)
      expect(rendered).to match(/#{plan.ehb}/)
    end

    it "should match css selector for standard plan" do
      expect(rendered).to have_css("i.fa-bookmark", text: /standard plan/i)
      expect(rendered).to have_css("h5.bg-title", text: /your current #{plan.active_year} plan/i)
    end

    it "should display the premium" do
      expect(rendered).to have_selector('h2.plan-premium', text: "100")
    end

    it "presents a download sbc link with filename and extension" do
      file_param = "filename=MyPlan.pdf"
      expect(rendered).to have_selector('a', text:'Summary of Benefits and Coverage')
      expect(rendered).to match(/#{file_param}/)
    end
  end

  context "with aptc" do
    before :each do
      allow(Caches::MongoidCache).to receive(:lookup).with(CarrierProfile, anything).and_return(carrier_profile)
      assign(:plan_hsa_status, plan_hsa_status)
      assign(:hbx_enrollment, hbx_enrollment)
      assign(:enrolled_hbx_enrollment_plan_ids, [plan.id])
      assign(:carrier_names_map, {})
      allow(plan).to receive(:total_employee_cost).and_return 100
      allow(plan).to receive(:is_csr?).and_return true
      allow(view).to receive(:current_cost).and_return(52)
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should display the premium" do
      expect(rendered).to have_selector('h2.plan-premium', text: "$52.00")
    end

    it "should display plan details" do
      expect(rendered).to match(/#{plan.name}/)
      expect(rendered).to match(/#{plan.carrier_profile}/)
      expect(rendered).to match(/#{plan.active_year}/)
      expect(rendered).to match(/#{plan.deductible}/)
      expect(rendered).to match(/#{plan.is_standard_plan}/)
      expect(rendered).to match(/#{plan.nationwide}/)
      expect(rendered).to match(/#{plan.total_employee_cost}/)
      expect(rendered).to match(/#{plan.plan_type}/)
      expect(rendered).to match(/#{plan.metal_level}/)
      expect(rendered).to match(/#{plan.hios_id}/)
    end

    it "should match css selector for standard plan" do
      expect(rendered).to have_css("i.fa-bookmark", text: /standard plan/i)
      expect(rendered).to have_css("h5.bg-title", text: /your current #{plan.active_year} plan/i)
    end

    it "should match fa-check-square for csr" do
      expect(rendered).to have_css("i.fa-check-square-o")
    end
  end
end
