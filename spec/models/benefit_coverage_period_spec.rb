require 'rails_helper'

RSpec.describe BenefitCoveragePeriod, type: :model do

  let(:benefit_sponsorship)       { FactoryGirl.create(:benefit_sponsorship) }
  let(:title)                     { "My new enrollment period" }
  let(:service_market)            { "individual" }
  let(:start_on)                  { Date.current.beginning_of_year }
  let(:end_on)                    { Date.current.end_of_year }
  let(:open_enrollment_start_on)  { Date.current.beginning_of_year - 2.months }
  let(:open_enrollment_end_on)    { Date.current.end_of_year + 2.months }
  let(:benefit_packages) do
    bp = FactoryGirl.build(:benefit_package)
    bpeg = FactoryGirl.build(:benefit_eligibility_element_group, benefit_package: bp)
    bp.to_a
  end

  let(:valid_params){
      {
        title: title,
        benefit_sponsorship: benefit_sponsorship,
        service_market: service_market,
        start_on: start_on,
        end_on: end_on,
        open_enrollment_start_on: open_enrollment_start_on,
        open_enrollment_end_on: open_enrollment_end_on,
        benefit_packages: benefit_packages
      }
    }

  context "a new instance" do
    context "with no arguments" do
      let(:params) {{}}

      it "should not save" do
        expect(BenefitCoveragePeriod.create(**params).valid?).to be_falsey
      end
    end

    context "missing any required argument" do
      before :each do
        subject.valid?
      end

      [:service_market, :start_on, :end_on, :open_enrollment_start_on, :open_enrollment_end_on].each do |property|
        it "should require #{property}" do
          expect(subject).to have_errors_on(property)
        end
      end
    end

    context "with all required attributes" do
      let(:params)                  { valid_params }
      let(:benefit_coverage_period) { BenefitCoveragePeriod.new(**params) }

      it "should be valid" do
        expect(benefit_coverage_period.valid?).to be_truthy
      end

      it "should save" do
        expect(benefit_coverage_period.save).to be_truthy
      end

      context "and it is saved" do
        before { benefit_coverage_period.save }

        it "should be findable by ID" do
          expect(BenefitCoveragePeriod.find(benefit_coverage_period.id)).to eq benefit_coverage_period
        end

        context "and a second lowest cost silver plan is specified" do
          let(:silver_plan) { FactoryGirl.create(:plan, metal_level: "silver") }
          let(:bronze_plan) { FactoryGirl.create(:plan, metal_level: "bronze") }
          let(:benefit_package) { FactoryGirl.create(:benefit_package) }

          context "and a silver plan is provided" do
            it "should set/get the assigned silver plan" do
              expect(benefit_coverage_period.second_lowest_cost_silver_plan = silver_plan).to eq silver_plan
              expect(benefit_coverage_period.second_lowest_cost_silver_plan).to eq silver_plan
            end
          end

          context "and a non-silver plan is provided" do
            it "should raise an error" do
              expect{benefit_coverage_period.second_lowest_cost_silver_plan = bronze_plan}.to raise_error(ArgumentError)
            end
          end

          context "and a non plan object is passed" do
            it "should raise an error" do
              expect{benefit_coverage_period.second_lowest_cost_silver_plan = benefit_package}.to raise_error(ArgumentError)
            end
          end

        end

        context "and open enrollment dates are queried" do
          it "should determine dates that are within open enrollment" do
            expect(benefit_coverage_period.open_enrollment_contains?(open_enrollment_start_on)).to be_truthy
            expect(benefit_coverage_period.open_enrollment_contains?(open_enrollment_end_on)).to be_truthy
          end

          it "should determine dates that are not within open enrollment" do
            expect(benefit_coverage_period.open_enrollment_contains?(open_enrollment_start_on - 1.day)).to be_falsey
            expect(benefit_coverage_period.open_enrollment_contains?(open_enrollment_end_on + 1.day)).to be_falsey
          end
        end

        context "and today is the last day to obtain benefits starting first of next month" do
          before do
            monthly_effective_date_deadline = 15
            TimeKeeper.set_date_of_record_unprotected!(Date.new(2015, 9, monthly_effective_date_deadline))
          end

          it "should determine the earliest effective date is next month" do
            expect(benefit_coverage_period.earliest_effective_date).to eq Date.new(2015, 10, 1)
          end
        end

        context "and today is past the deadline to obtain benefits starting first of next month" do
          before do
            monthly_effective_date_deadline = 15
            TimeKeeper.set_date_of_record_unprotected!(Date.new(2015, 9, (monthly_effective_date_deadline + 1)))
          end

          it "should determine the earliest effective date is month after next" do
            expect(benefit_coverage_period.earliest_effective_date).to eq Date.new(2015, 11, 1)
          end
        end
      end
    end
  end

  context "elected_plans_by_enrollment_members" do
    let(:benefit_coverage_period) { BenefitCoveragePeriod.new(start_on: (TimeKeeper.date_of_record - 2.months).to_date) }
    let(:c1) {FactoryGirl.create(:consumer_role)}
    let(:c2) {FactoryGirl.create(:consumer_role)}
    let(:member1) {double(person: double(consumer_role: c1))}
    let(:member2) {double(person: double(consumer_role: c2))}
    let(:plan1) { FactoryGirl.create(:plan_with_premium_tables, market: 'individual', metal_level: 'gold', csr_variant_id: '01', active_year: TimeKeeper.date_of_record.year, hios_id: "11111111122302-01") }
    let(:plan2) { FactoryGirl.create(:plan_with_premium_tables, market: 'individual', metal_level: 'gold', csr_variant_id: '01', active_year: TimeKeeper.date_of_record.year - 1, hios_id: "11111111122303-01") }
    let(:plan3) { FactoryGirl.create(:plan_with_premium_tables, market: 'individual', metal_level: 'gold', csr_variant_id: '01', active_year: TimeKeeper.date_of_record.year, hios_id: "11111111122304-01") }
    let(:plan4) { FactoryGirl.create(:plan, market: 'individual', active_year: TimeKeeper.date_of_record.year, hios_id: "11111111122305-02") }
    let(:benefit_package1) {double(benefit_ids: [plan1.id, plan2.id])}
    let(:benefit_package2) {double(benefit_ids: [plan3.id, plan4.id])}
    let(:rule) {double}

    before :each do
      Plan.delete_all
      allow(benefit_coverage_period).to receive(:benefit_packages).and_return [benefit_package1, benefit_package2]
      allow(InsuredEligibleForBenefitRule).to receive(:new).and_return rule
    end

    it "when satisfied" do
      allow(rule).to receive(:satisfied?).and_return [true, 'ok']
      plans = [plan1, plan3]
      expect(benefit_coverage_period.elected_plans_by_enrollment_members([member1, member2], 'health')).to eq plans
    end

    it "when not satisfied" do
      allow(rule).to receive(:satisfied?).and_return [false, 'ok']
      plans = []
      expect(benefit_coverage_period.elected_plans_by_enrollment_members([member1, member2], 'health')).to eq plans
    end
  end
end
