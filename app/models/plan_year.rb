class PlanYear
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  include AASM

  embedded_in :employer_profile

  # Plan Year time period
  field :start_on, type: Date
  field :end_on, type: Date

  field :open_enrollment_start_on, type: Date
  field :open_enrollment_end_on, type: Date

  field :imported_plan_year, type: Boolean, default: false 
  # Number of full-time employees
  field :fte_count, type: Integer, default: 0

  # Number of part-time employess
  field :pte_count, type: Integer, default: 0

  # Number of Medicare Second Payers
  field :msp_count, type: Integer, default: 0

  # Workflow attributes
  field :aasm_state, type: String, default: :draft

  embeds_many :benefit_groups, cascade_callbacks: true
  embeds_many :workflow_state_transitions, as: :transitional

  accepts_nested_attributes_for :benefit_groups, :workflow_state_transitions

  validates_presence_of :start_on, :end_on, :open_enrollment_start_on, :open_enrollment_end_on, :message => "is invalid"

  validate :open_enrollment_date_checks

  scope :not_yet_active, ->{ any_in(aasm_state: %w(published enrolling enrolled)) }
  scope :published, ->{ any_in(aasm_state: %w(published enrolling enrolled active suspended)) }

  def parent
    raise "undefined parent employer_profile" unless employer_profile?
    self.employer_profile
  end

  def start_on=(new_date)
    new_date = Date.parse(new_date) if new_date.is_a? String
    write_attribute(:start_on, new_date.beginning_of_day)
  end

  def end_on=(new_date)
    new_date = Date.parse(new_date) if new_date.is_a? String
    write_attribute(:end_on, new_date.end_of_day)
  end

  def open_enrollment_start_on=(new_date)
    new_date = Date.parse(new_date) if new_date.is_a? String
    write_attribute(:open_enrollment_start_on, new_date.beginning_of_day)
  end

  def open_enrollment_end_on=(new_date)
    new_date = Date.parse(new_date) if new_date.is_a? String
    write_attribute(:open_enrollment_end_on, new_date.end_of_day)
  end

  alias_method :effective_date=, :start_on=
  alias_method :effective_date, :start_on

  def hbx_enrollments
    @hbx_enrollments = [] if benefit_groups.size == 0
    return @hbx_enrollments if defined? @hbx_enrollments
    @hbx_enrollments = HbxEnrollment.find_by_benefit_groups(benefit_groups)
  end

  def employee_participation_percent
    return "-" if eligible_to_enroll_count == 0
    "#{(total_enrolled_count / eligible_to_enroll_count.to_f * 100).round(2)}%"
  end

  def editable?
    !benefit_groups.any?(&:assigned?)
  end

  def open_enrollment_contains?(date)
    (open_enrollment_start_on <= date) && (date <= open_enrollment_end_on)
  end

  def coverage_period_contains?(date)
    return (start_on <= date) if (end_on.blank?)
    (start_on <= date) && (date <= end_on)
  end

  def minimum_employer_contribution
    unless benefit_groups.size == 0
      benefit_groups.map do |benefit_group|
        benefit_group.relationship_benefits.select do |relationship_benefit|
          relationship_benefit.relationship == "employee"
        end.min_by do |relationship_benefit|
          relationship_benefit.premium_pct
        end
      end.map(&:premium_pct).first
    end
  end

  def assigned_census_employees
    benefit_groups.flat_map(){ |benefit_group| benefit_group.census_employees.active }
  end

  def assigned_census_employees_without_owner
    benefit_groups.flat_map(){ |benefit_group| benefit_group.census_employees.active.non_business_owner }
  end

  def open_to_publish?
    employer_profile.plan_years.reject{ |py| py==self }.any?(&:published?)
  end

  # does the plan year violate model integrity relative to publishing
  def is_application_unpublishable?
    application_errors.blank? ? false : true
  end

  # is the plan year compliant with all regulations
  def is_application_valid?
    application_eligibility_warnings.blank? ? true : false
  end

  # Check plan year for violations of model integrity relative to publishing
  def application_errors
    errors = {}

    if benefit_groups.size == 0
      errors.merge!({benefit_groups: "You must create at least one benefit group to publish a plan year"})
    end

    if employer_profile.census_employees.active.to_set != assigned_census_employees.to_set
      errors.merge!({benefit_groups: "Every employee must be assigned to a benefit group defined for the published plan year"})
    end

    if employer_profile.ineligible?
      errors.merge!({employer_profile: "This employer is ineligible to enroll for coverage at this time"})
    end

    if open_to_publish?
      errors.merge!({publish: "You may only have one published plan year at a time"})
    end

    errors
  end

  # Check plan year application for regulatory compliance
  def application_eligibility_warnings
    warnings = application_errors

    unless employer_profile.organization.primary_office_location.address.state.to_s.downcase == HbxProfile::StateAbbreviation.to_s.downcase
      warnings.merge!({primary_office_location: "Primary office must be located in #{HbxProfile::StateName}"})
    end

    # Employer is in ineligible state from prior enrollment activity
    if aasm_state == "ineligible"
      warnings.merge!({ineligible: "Employer is under a period of ineligibility for enrollment on the HBX"})
    end

    # Maximum company size at time of initial registration on the HBX
    if fte_count > HbxProfile::ShopSmallMarketFteCountMaximum
      warnings.merge!({fte_count: "Number of full time equivalents (FTEs) exceeds maximum allowed (#{HbxProfile::ShopSmallMarketFteCountMaximum})"})
    end

    # Exclude Jan 1 effective date from certain checks
    unless effective_date.yday == 1
      # Employer contribution toward employee premium must meet minimum
      if benefit_groups.size > 0 && (minimum_employer_contribution < HbxProfile::ShopEmployerContributionPercentMinimum)
        warnings.merge!({minimum_employer_contribution: "Employer contribution percent toward employee premium (#{minimum_employer_contribution.to_i}%) is less than minimum allowed (#{HbxProfile::ShopEmployerContributionPercentMinimum.to_i}%)"})
      end
    end

    warnings
  end

  # All active employees present on the roster with benefit groups belonging to this plan year
  def eligible_to_enroll
    return @eligible if defined? @eligible
    @eligible ||= find_census_employees.active
  end

  def waived
    return @waived if defined? @waived
    @waived ||= find_census_employees.waived
  end

  def waived_count
    waived.count
  end

  def covered
    return @covered if defined? @covered
    @covered ||= find_census_employees.covered
  end

  def find_census_employees
    return @census_employees if defined? @census_employees
    @census_employees ||= CensusEmployee.by_benefit_group_ids(benefit_group_ids)
  end

  def covered_count
    covered.count
  end

  def benefit_group_ids
    benefit_groups.collect(&:id)
  end

  def eligible_to_enroll_count
    eligible_to_enroll.size
  end

  # Employees who selected or waived and are not owners or direct family members of owners
  def non_business_owner_enrolled
    enrolled.non_business_owner
  end

  def non_business_owner_enrollment_count
    non_business_owner_enrolled.size
  end

  # Any employee who selected or waived coverage
  def enrolled
    eligible_to_enroll.enrolled
  end

  def total_enrolled_count
    enrolled.size
  end

  def enrollment_ratio
    if eligible_to_enroll_count == 0
      0
    else
      ((total_enrolled_count * 1.0)/ eligible_to_enroll_count)
    end
  end

  def minimum_enrolled_count
    (HbxProfile::ShopEnrollmentParticipationRatioMinimum * eligible_to_enroll_count).ceil
  end

  def additional_required_participants_count
    if total_enrolled_count < minimum_enrolled_count
      minimum_enrolled_count - total_enrolled_count
    else
      0.0
    end
  end

  def is_enrollment_valid?
    enrollment_errors.blank? ? true : false
  end

  def is_open_enrollment_closed?
    open_enrollment_end_on.end_of_day < TimeKeeper.date_of_record.beginning_of_day
  end

  # Determine enrollment composition compliance with HBX-defined guards
  def enrollment_errors
    errors = {}

    # At least one employee must be enrollable.
    if eligible_to_enroll_count == 0
      errors.merge!(eligible_to_enroll_count: "at least one employee must be eligible to enroll")
    end

    # At least one employee who isn't an owner or family member of owner must enroll
    if non_business_owner_enrollment_count < eligible_to_enroll_count
      if non_business_owner_enrollment_count < HbxProfile::ShopEnrollmentNonOwnerParticipationMinimum
        errors.merge!(non_business_owner_enrollment_count: "at least #{HbxProfile::ShopEnrollmentNonOwnerParticipationMinimum} non-owner employee must enroll")
      end
    end

    # January 1 effective date exemption(s)
    unless effective_date.yday == 1
      # Verify ratio for minimum number of eligible employees that must enroll is met
      if enrollment_ratio < HbxProfile::ShopEnrollmentParticipationRatioMinimum
        errors.merge!(enrollment_ratio: "number of eligible participants enrolling (#{total_enrolled_count}) is less than minimum required #{eligible_to_enroll_count * HbxProfile::ShopEnrollmentParticipationRatioMinimum}")
      end
    end

    errors
  end

  def employees_are_matchable?
    %w(published enrolling enrolled active).include? aasm_state
  end

  class << self
    def find(id)
      organizations = Organization.where("employer_profile.plan_years._id" => BSON::ObjectId.from_string(id))
      organizations.size > 0 ? organizations.first.employer_profile.plan_years.unscoped.detect { |py| py._id.to_s == id.to_s} : nil
    end

    def shop_enrollment_timetable(new_effective_date)
      effective_date = new_effective_date.to_date.beginning_of_month
      prior_month = effective_date - 1.month
      plan_year_start_on = effective_date
      plan_year_end_on = effective_date + 1.year - 1.day
      employer_initial_application_earliest_start_on = (effective_date - HbxProfile::ShopPlanYearPublishBeforeEffectiveDateMaximum)
      employer_initial_application_earliest_submit_on = employer_initial_application_earliest_start_on
      employer_initial_application_latest_submit_on   = ("#{prior_month.year}-#{prior_month.month}-#{HbxProfile::ShopPlanYearPublishedDueDayOfMonth}").to_date
      open_enrollment_earliest_start_on     = effective_date - HbxProfile::ShopOpenEnrollmentPeriodMaximum.months
      open_enrollment_latest_start_on       = ("#{prior_month.year}-#{prior_month.month}-#{HbxProfile::ShopOpenEnrollmentBeginDueDayOfMonth}").to_date
      open_enrollment_latest_end_on         = ("#{prior_month.year}-#{prior_month.month}-#{HbxProfile::ShopOpenEnrollmentEndDueDayOfMonth}").to_date
      binder_payment_due_date               = first_banking_date_prior ("#{prior_month.year}-#{prior_month.month}-#{HbxProfile::ShopBinderPaymentDueDayOfMonth}")


      timetable = {
        effective_date: effective_date,
        plan_year_start_on: plan_year_start_on,
        plan_year_end_on: plan_year_end_on,
        employer_initial_application_earliest_start_on: employer_initial_application_earliest_start_on,
        employer_initial_application_earliest_submit_on: employer_initial_application_earliest_submit_on,
        employer_initial_application_latest_submit_on: employer_initial_application_latest_submit_on,
        open_enrollment_earliest_start_on: open_enrollment_earliest_start_on,
        open_enrollment_latest_start_on: open_enrollment_latest_start_on,
        open_enrollment_latest_end_on: open_enrollment_latest_end_on,
        binder_payment_due_date: binder_payment_due_date
      }

      timetable
    end

    def check_start_on(start_on)
      start_on = start_on.to_date
      shop_enrollment_times = shop_enrollment_timetable(start_on)

      if start_on.day != 1
        result = "failure"
        msg = "start on must be first day of the month"
      elsif TimeKeeper.date_of_record > shop_enrollment_times[:open_enrollment_latest_start_on]
        result = "failure"
        msg = "must choose a start on date #{(TimeKeeper.date_of_record - HbxProfile::ShopOpenEnrollmentBeginDueDayOfMonth + HbxProfile::ShopOpenEnrollmentPeriodMaximum.months).beginning_of_month} or later"
      end
      {result: (result || "ok"), msg: (msg || "")}
    end

    def calculate_start_on_dates
      # Today - 5 + 2.months).beginning_of_month
      # July 6 => Sept 1
      # July 1 => Aug 1
      start_on = (TimeKeeper.date_of_record - HbxProfile::ShopOpenEnrollmentBeginDueDayOfMonth + HbxProfile::ShopOpenEnrollmentPeriodMaximum.months).beginning_of_month
      end_on = (TimeKeeper.date_of_record + HbxProfile::ShopPlanYearPublishBeforeEffectiveDateMaximum).beginning_of_month
      dates = (start_on..end_on).select {|t| t == t.beginning_of_month}
    end

    def calculate_start_on_options
      calculate_start_on_dates.map {|date| [date.strftime("%B %Y"), date.to_s(:db) ]}
    end

    def calculate_open_enrollment_date(start_on)
      start_on = start_on.to_date

      # open_enrollment_start_on = [start_on - 1.month, TimeKeeper.date_of_record].max
      # candidate_open_enrollment_end_on = Date.new(open_enrollment_start_on.year.to_i, open_enrollment_start_on.month.to_i, HbxProfile::ShopOpenEnrollmentEndDueDayOfMonth)

      # open_enrollment_end_on = if (candidate_open_enrollment_end_on - open_enrollment_start_on) < (HbxProfile::ShopOpenEnrollmentPeriodMinimum - 1)
      #   candidate_open_enrollment_end_on.next_month
      # else
      #   candidate_open_enrollment_end_on
      # end

      open_enrollment_start_on = [(start_on - HbxProfile::ShopOpenEnrollmentPeriodMaximum.months), TimeKeeper.date_of_record].max

      #candidate_open_enrollment_end_on = Date.new(open_enrollment_start_on.year, open_enrollment_start_on.month, HbxProfile::ShopOpenEnrollmentEndDueDayOfMonth)

      #open_enrollment_end_on = if (candidate_open_enrollment_end_on - open_enrollment_start_on) < (HbxProfile::ShopOpenEnrollmentPeriodMinimum - 1)
      #  candidate_open_enrollment_end_on.next_month
      #else
      #  candidate_open_enrollment_end_on
      #end

      open_enrollment_end_on = shop_enrollment_timetable(start_on)[:open_enrollment_latest_end_on]

      binder_payment_due_date = map_binder_payment_due_date_by_start_on(start_on)

      {open_enrollment_start_on: open_enrollment_start_on,
       open_enrollment_end_on: open_enrollment_end_on,
       binder_payment_due_date: binder_payment_due_date}
    end

    def map_binder_payment_due_date_by_start_on(start_on)
      dates_map = {}
      {
        "2015-01-01" => '2014,12,12',
        "2015-02-01" => '2015,1,13',
        "2015-03-01" => '2015,2,12',
        "2015-04-01" => '2015,3,12',
        "2015-05-01" => '2015,4,14',
        "2015-06-01" => '2015,5,12',
        "2015-07-01" => '2015,6,12',
        "2015-08-01" => '2015,7,14',
        "2015-09-01" => '2015,8,12',
        "2015-10-01" => '2015,9,14',
        "2015-11-01" => '2015,10,14',
        "2015-12-01" => '2015,11,12',
        "2016-01-01" => '2015,12,14',
        "2016-02-01" => '2016,1,12',
        "2016-03-01" => '2016,2,12',
        "2016-04-01" => '2016,3,14',
        "2016-05-01" => '2016,4,12',
        "2016-06-01" => '2016,5,12',
        "2016-07-01" => '2016,6,14',
        "2016-08-01" => '2016,7,12',
        "2016-09-01" => '2016,8,12',
        "2016-10-01" => '2016,9,13',
        "2016-11-01" => '2016,10,12',
        "2016-12-01" => '2016,11,14',
        "2017-01-01" => '2016,12,13'}.each_pair do |k, v|
          dates_map[k] = Date.strptime(v, '%Y,%m,%d')
        end

      dates_map[start_on.strftime('%Y-%m-%d')] || shop_enrollment_timetable(start_on)[:binder_payment_due_date]
    end

    ## TODO - add holidays
    def first_banking_date_prior(date_value)
      date = date_value.to_date
      date = date - 1 if date.saturday?
      date = date - 2 if date.sunday?
      date
    end
  end

  aasm do
    state :draft, initial: true

    state :publish_pending      # Plan application as submitted has warnings
    state :eligibility_review   # Plan application was submitted with warning and is under review by HBX officials
    state :published,         :after_enter => :accept_application     # Plan is finalized. Employees may view benefits, but not enroll
    state :published_invalid, :after_enter => :decline_application    # Non-compliant plan application was forced-published

    state :enrolling                                      # Published plan has entered open enrollment
    state :enrolled, :after_enter => :ratify_enrollment   # Published plan open enrollment has ended and is eligible for coverage,
                                                          #   but effective date is in future
    state :canceled                                       # Published plan open enrollment has ended and is ineligible for coverage

    state :active         # Published plan year is in-force

    state :suspended      # Premium payment is 61-90 days past due and coverage is currently not in effect
    state :terminated     # Coverage under this application is terminated
    state :ineligible     # Application is non-compliant for enrollment
    state :expired        # Non-published plans are expired following their end on date


    # Change enrollment state, in-force plan year and clean house on any plan year applications from prior year
    event :advance_date, :after => :record_transition do
      transitions from: :enrolled,  to: :active,    :guard  => :is_event_date_valid?
      transitions from: :published, to: :enrolling, :guard  => :is_event_date_valid?
      transitions from: :enrolling, to: :enrolled,  :guards => [:is_open_enrollment_closed?, :is_enrollment_valid?]
      transitions from: :enrolling, to: :canceled,  :guard  => :is_open_enrollment_closed?, :after => :deny_enrollment

      transitions from: :active, to: :terminated, :guard => :is_event_date_valid?
      transitions from: [:draft, :ineligible, :publish_pending, :published_invalid, :eligibility_review], to: :expired, :guard => :is_plan_year_end?
    end

    ## Application eligibility determination process

    # Submit plan year application
    event :publish, :after => :record_transition do
      transitions from: :draft, to: :draft,     :guard => :is_application_unpublishable?, :after => :report_unpublishable
      transitions from: :draft, to: :enrolling, :guard => [:is_application_valid?, :is_event_date_valid?], :after => :accept_application
      transitions from: :draft, to: :published, :guard => :is_application_valid?
      transitions from: :draft, to: :publish_pending
    end

    # Returns plan to draft state for edit
    event :withdraw_pending, :after => :record_transition do
      transitions from: :publish_pending, to: :draft
    end

    # Plan as submitted failed eligibility check
    event :force_publish, :after => :record_transition do
      transitions from: :publish_pending, to: :published_invalid
    end

    # Employer requests review of invalid application determination
    event :request_eligibility_review, :after => :record_transition do
      transitions from: :published_invalid, to: :eligibility_review, :guard => :is_within_review_period?
    end

    # Upon review, application ineligible status overturned and deemed eligible
    event :grant_eligibility, :after => :record_transition do
      transitions from: :eligibility_review, to: :published
    end

    # Upon review, submitted application ineligible status verified ineligible
    event :deny_eligibility, :after => :record_transition do
      transitions from: :eligibility_review, to: :published_invalid
    end

    # Enrollment processed stopped due to missing binder payment
    event :cancel, :after => :record_transition do
      transitions from: :enrolled, to: :canceled
    end

    # Coverage disabled due to non-payment
    event :suspend, :after => :record_transition do
      transitions from: :active, to: :suspended
    end

    # Coverage termianted due to non-payment
    event :terminate, :after => :record_transition do
      transitions from: [:active, :suspended], to: :terminated
    end

    # Admin ability to reset application
    event :revert_application, :after => :record_transition do
      transitions from: [:active, :ineligible, :published_invalid, :eligibility_review, :published], to: :draft
    end
  end

  def accept_application
    transition_success = employer_profile.application_accepted!
    send_employee_invites if transition_success
  end

  def decline_application
    employer_profile.application_declined!
  end

  def ratify_enrollment
    employer_profile.enrollment_ratified!
  end

  def deny_enrollment
    employer_profile.enrollment_denied!
  end

  def is_eligible_to_match_census_employees?
    (benefit_groups.size > 0) and
    (published? or enrolling? or enrolled? or active?)
  end

  def is_within_review_period?
    published_invalid? and
    (latest_workflow_state_transition.transition_at >
      (TimeKeeper.date_of_record - HbxProfile::ShopApplicationAppealPeriodMaximum))
  end

  # def shoppable? # is_eligible_to_shop?
  #   (benefit_groups.size > 0) and
  #   ((published? and employer_profile.shoppable?))
  # end

  def latest_workflow_state_transition
    workflow_state_transitions.order_by(:'transition_at'.desc).limit(1).first
  end

  def is_before_start?
    TimeKeeper.date_of_record.end_of_day < start_on
  end

private
  def is_event_date_valid?
    today = TimeKeeper.date_of_record
    valid = case aasm_state
    when "published", "draft"
      today >= open_enrollment_start_on
    when "enrolling"
      today.end_of_day >= open_enrollment_end_on
    when "enrolled"
      today >= start_on
    when "active"
      today >= end_on
    else
      false
    end

    valid
  end

  def is_plan_year_end?
    TimeKeeper.date_of_record.end_of_day == end_on
  end

  def record_transition
    self.workflow_state_transitions << WorkflowStateTransition.new(
      from_state: aasm.from_state,
      to_state: aasm.to_state
    )
  end

  def send_employee_invites
    benefit_groups.each do |bg|
      bg.census_employees.each do |ce|
        Invitation.invite_employee!(ce)
      end
    end
  end

    # attempted to publish but plan year violates publishing plan model integrity
  def report_unpublishable
    application_eligibility_warnings.each_pair(){ |key, value| errors.add(key, value) }
  end

  def within_review_period?
    (latest_workflow_state_transition.transition_at.end_of_day + HbxProfile::ShopApplicationAppealPeriodMaximum) > TimeKeeper.date_of_record
  end

  def duration_in_days(duration)
    (duration / 1.day).to_i
  end

  def open_enrollment_date_checks
    return if start_on.blank? || end_on.blank? || open_enrollment_start_on.blank? || open_enrollment_end_on.blank?
    return if imported_plan_year
    if start_on.day != 1
      errors.add(:start_on, "must be first day of the month")
    end

    if end_on != Date.civil(end_on.year, end_on.month, -1)
      errors.add(:end_on, "must be last day of the month")
    end

    # TODO: Create HBX object with configuration settings including shop_plan_year_maximum_in_days
    shop_plan_year_maximum_in_days = 365
    if (end_on - start_on).to_i > shop_plan_year_maximum_in_days
      errors.add(:end_on, "must be less than #{shop_plan_year_maximum_in_days} days from start date")
    end

    if open_enrollment_end_on > start_on
      errors.add(:start_on, "can't occur before open enrollment end date")
    end

    # if TimeKeeper.date_of_record > ("#{prior_month.year}-#{prior_month.month}-#{HbxProfile::ShopOpenEnrollmentBeginDueDayOfMonth}").to_date
    #  errors.add(:start_on, "must choose a start on date #{effect_date + 1.month} or later")
    # end

    if open_enrollment_end_on < open_enrollment_start_on
      errors.add(:open_enrollment_end_on, "can't occur before open enrollment start date")
    end

    if (open_enrollment_end_on - open_enrollment_start_on).to_i < (HbxProfile::ShopOpenEnrollmentPeriodMinimum - 1)
     errors.add(:open_enrollment_end_on, "open enrollment period is less than minumum: #{HbxProfile::ShopOpenEnrollmentPeriodMinimum} days")
    end

    if (open_enrollment_end_on - open_enrollment_start_on) > HbxProfile::ShopOpenEnrollmentPeriodMaximum.months
     errors.add(:open_enrollment_end_on, "open enrollment period is greater than maximum: #{HbxProfile::ShopOpenEnrollmentPeriodMaximum} months")
    end

    if start_on + HbxProfile::ShopPlanYearPeriodMinimum < end_on
      errors.add(:end_on, "plan year period is less than minumum: #{duration_in_days(HbxProfile::ShopPlanYearPeriodMinimum)} days")
    end

    if start_on + HbxProfile::ShopPlanYearPeriodMaximum > end_on
      errors.add(:end_on, "plan year period is greater than maximum: #{duration_in_days(HbxProfile::ShopPlanYearPeriodMaximum)} days")
    end

    if (start_on - HbxProfile::ShopPlanYearPublishBeforeEffectiveDateMaximum) > TimeKeeper.date_of_record
     errors.add(:start_on, "may not start application before " \
        "#{(start_on - HbxProfile::ShopPlanYearPublishBeforeEffectiveDateMaximum).to_date} with #{start_on} effective date")
    end

    if open_enrollment_end_on - (start_on - 1.month) >= HbxProfile::ShopOpenEnrollmentEndDueDayOfMonth
     errors.add(:open_enrollment_end_on, "open enrollment must end on or before the #{HbxProfile::ShopOpenEnrollmentEndDueDayOfMonth.ordinalize} day of the month prior to effective date")
    end
  end
end
