require "rails_helper"

RSpec.describe "employers/employer_profiles/my_account/_benefits.html.erb" do
  let(:employer_profile) { FactoryGirl.create(:employer_profile) }
  let(:plan_year) { FactoryGirl.create(:plan_year) }
  let(:benefit_group) { FactoryGirl.create(:benefit_group, plan_year: plan_year) }
  let(:plan) { FactoryGirl.create(:plan) }

  before :each do
    allow(benefit_group).to receive(:reference_plan).and_return(plan)
    allow(plan_year).to receive(:benefit_groups).and_return([benefit_group])
    allow(benefit_group).to receive(:effective_on_offset).and_return 30
    assign(:plan_years, [plan_year])
    assign(:employer_profile, employer_profile)
  end

  it "should display contribution pct by integer" do
    render "employers/employer_profiles/my_account/benefits"
    expect(rendered).to match(/Coverage - Benefits You Offer/)
    plan_year.benefit_groups.first.relationship_benefits.map(&:premium_pct).each do |pct|
      expect(rendered).to have_selector("td", text: "#{pct.to_i}%")
    end
  end
  
  it "should display title by effective_on_offset" do
    render "employers/employer_profiles/my_account/benefits"
    expect(rendered).to match /First of the month following 30 days/
  end
end
