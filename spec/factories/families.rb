FactoryGirl.define do
  factory :family do
    sequence(:e_case_id) {|n| "abc#{n}12xyz#{n}"}
    renewal_consent_through_year  2017
    submitted_at Time.now
    updated_at "user"

    trait :with_primay_family_member do
      family_members {[FamilyMember.new(is_primary_applicant: true, is_consent_applicant:true)]}
    end
  end
end
