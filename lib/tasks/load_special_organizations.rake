namespace :seed_special_organization do
  desc "Load the organization for dental"
  task :dental => :environment do
    puts "::: Creating Organization for Dental :::"
    # Employer addresses
    broker_agency_1 = BrokerAgencyProfile.last
    Organization.where(legal_name: "Global Systems For Dental").destroy_all
    org_add = Address.new(kind: "work", address_1: "823 Cosmic Way, NW", city: "Washington", state: "DC", zip: "20001")
    org_phone = Phone.new(kind: "main", area_code: "802", number: "123-1213")
    org_email = Email.new(kind: "work", address: "info@organization1.com")
    org_off_loc = OfficeLocation.new(is_primary: true, address: org_add, phone: org_phone)

    org = Organization.new(
      dba: "detal",
      legal_name: "Global Systems For Dental",
      fein: 123456000,
      office_locations: [org_off_loc]
    )

    org_employer_profile = org.create_employer_profile(
      entity_kind: "governmental_employer",
      broker_agency_profile: broker_agency_1
    )

    org_plan_year = org_employer_profile.plan_years.build(
      start_on: 0.days.ago.beginning_of_year.to_date,
      end_on: 0.days.ago.end_of_year.to_date,
      open_enrollment_start_on: (0.days.ago.beginning_of_year.to_date - 2.months).beginning_of_month,
      open_enrollment_end_on: (0.days.ago.beginning_of_year.to_date - 2.months).end_of_month,
      fte_count: 12,
      pte_count: 1
    )

    plans = Plan.where(coverage_kind: "dental").where(active_year: Date.today.year).select{|p| p.premium_tables.present? }
    org_benefit_group = org_plan_year.benefit_groups.build(
      effective_on_kind:  "date_of_hire",
      terminate_on_kind:  "end_of_month",
      plan_option_kind: "metal_level", 
      effective_on_offset:  30,
      employer_max_amt_in_cents:  500_00,
      elected_plan_ids: plans.map(&:id),
      reference_plan: plans.last
    )

    BenefitGroup::PERSONAL_RELATIONSHIP_KINDS.each do |relationship|
      org_benefit_group.relationship_benefits.build(relationship: relationship.to_s, premium_pct: 0, offered: true)
    end

    org.save!
  end

  desc "Load the organization for individual"
  task :individual => :environment do
    puts "::: Creating Organization for individual :::"
    # Employer addresses
    broker_agency_1 = BrokerAgencyProfile.last
    Organization.where(legal_name: "Global Systems For Individual").destroy_all
    org_add = Address.new(kind: "work", address_1: "823 Cosmic Way, NW", city: "Washington", state: "DC", zip: "20001")
    org_phone = Phone.new(kind: "main", area_code: "802", number: "123-1213")
    org_email = Email.new(kind: "work", address: "info@organization1.com")
    org_off_loc = OfficeLocation.new(is_primary: true, address: org_add, phone: org_phone)

    org = Organization.new(
      dba: "individual",
      legal_name: "Global Systems For Individual",
      fein: 123456111,
      office_locations: [org_off_loc]
    )

    org_employer_profile = org.create_employer_profile(
      entity_kind: "governmental_employer",
      broker_agency_profile: broker_agency_1
    )

    org_plan_year = org_employer_profile.plan_years.build(
      start_on: 0.days.ago.beginning_of_year.to_date,
      end_on: 0.days.ago.end_of_year.to_date,
      open_enrollment_start_on: (0.days.ago.beginning_of_year.to_date - 2.months).beginning_of_month,
      open_enrollment_end_on: (0.days.ago.beginning_of_year.to_date - 2.months).end_of_month,
      fte_count: 12,
      pte_count: 1
    )

    plans = Plan.where(market: "individual").where(active_year: Date.today.year).select{|p| p.premium_tables.present? }
    org_benefit_group = org_plan_year.benefit_groups.build(
      effective_on_kind:  "date_of_hire",
      terminate_on_kind:  "end_of_month",
      plan_option_kind: "metal_level", 
      effective_on_offset:  30,
      employer_max_amt_in_cents:  500_00,
      elected_plan_ids: plans.map(&:id),
      reference_plan: plans.last
    )

    BenefitGroup::PERSONAL_RELATIONSHIP_KINDS.each do |relationship|
      org_benefit_group.relationship_benefits.build(relationship: relationship.to_s, premium_pct: 0, offered: true)
    end

    org.save!
  end
end
