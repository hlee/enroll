FactoryGirl.define do
  factory :family do
    association :person
    e_case_id do
      Forgery('basic').text(:allow_lower   => false,
                            :allow_upper   => false,
                            :allow_numeric => true,
                            :allow_special => false, :exactly => 9)
    end
    renewal_consent_through_year  2017
    submitted_at Time.now
    updated_at "user"

    trait :with_primary_family_member do
      family_members { [FactoryGirl.build(:family_member, family: self, is_primary_applicant: true, is_active: true, person: person)] }
    end

    after :create do |f, evaluator|
      f.households.first.add_household_coverage_member(f.family_members.first)
      f.save
    end
  end
end

FactoryGirl.define do
  factory(:individual_market_family, class: Family) do
    transient do
      primary_person { FactoryGirl.create(:person, :with_consumer_role) }
    end

    family_members { [
      FactoryGirl.create(:family_member, family: self, is_primary_applicant: true, is_active: true, person: primary_person)
    ] }

    after :create do |f, evaluator|
      f.households.first.add_household_coverage_member(f.family_members.first)
    end
  end
end
