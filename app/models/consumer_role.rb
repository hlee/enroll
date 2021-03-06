class ConsumerRole
  RESIDENCY_VERIFICATION_REQUEST_EVENT_NAME = "local.enroll.residency.verification_request"

  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  include Acapi::Notifiers
  include AASM

  embedded_in :person

  VLP_AUTHORITY_KINDS = %w(ssa dhs hbx curam)
  NATURALIZED_CITIZEN_STATUS = "naturalized_citizen"
  INDIAN_TRIBE_MEMBER_STATUS = "indian_tribe_member"
  US_CITIZEN_STATUS = "us_citizen"
  NOT_LAWFULLY_PRESENT_STATUS = "not_lawfully_present_in_us"
  ALIEN_LAWFULLY_PRESENT_STATUS = "alien_lawfully_present"

  US_CITIZEN_STATUS_KINDS = %W(
  us_citizen
  naturalized_citizen
  indian_tribe_member
  )
  CITIZEN_STATUS_KINDS = %w(
      us_citizen
      naturalized_citizen
      alien_lawfully_present
      lawful_permanent_resident
      indian_tribe_member
      undocumented_immigrant
      not_lawfully_present_in_us
  )

  ACA_ELIGIBLE_CITIZEN_STATUS_KINDS = %W(
      us_citizen
      naturalized_citizen
      indian_tribe_member
  )

  # FiveYearBarApplicabilityIndicator ??
  field :five_year_bar, type: Boolean, default: false
  field :requested_coverage_start_date, type: Date, default: TimeKeeper.date_of_record
  field :aasm_state, type: String, default: "verifications_pending"

  delegate :citizen_status,:vlp_verified_date, :vlp_authority, :vlp_document_id, to: :lawful_presence_determination_instance
  delegate :citizen_status=,:vlp_verified_date=, :vlp_authority=, :vlp_document_id=, to: :lawful_presence_determination_instance

  field :is_state_resident, type: Boolean
  field :residency_determined_at, type: DateTime

  field :is_applicant, type: Boolean  # Consumer is applying for benefits coverage
  field :birth_location, type: String
  field :marital_status, type: String
  field :is_active, type: Boolean, default: true

  field :raw_event_responses, type: Array, default: [] #e.g. [{:lawful_presence_response => payload}]
  field :bookmark_url, type: String, default: nil
  field :contact_method, type: String, default: "Only Paper communication"
  field :language_preference, type: String, default: "English"

  delegate :hbx_id, :hbx_id=, to: :person, allow_nil: true
  delegate :ssn,    :ssn=,    to: :person, allow_nil: true
  delegate :no_ssn,    :no_ssn=,    to: :person, allow_nil: true
  delegate :dob,    :dob=,    to: :person, allow_nil: true
  delegate :gender, :gender=, to: :person, allow_nil: true

  delegate :is_incarcerated,    :is_incarcerated=,   to: :person, allow_nil: true

  delegate :race,               :race=,              to: :person, allow_nil: true
  delegate :ethnicity,          :ethnicity=,         to: :person, allow_nil: true
  delegate :is_disabled,        :is_disabled=,       to: :person, allow_nil: true
  delegate :tribal_id,          :tribal_id=,         to: :person, allow_nil: true

  embeds_many :documents, as: :documentable
  embeds_many :vlp_documents, as: :documentable
  embeds_many :workflow_state_transitions, as: :transitional

  accepts_nested_attributes_for :person, :workflow_state_transitions, :vlp_documents

  validates_presence_of :dob, :gender, :is_applicant
  #validate :ssn_or_no_ssn

  validates :vlp_authority,
    allow_blank: true,
    inclusion: { in: VLP_AUTHORITY_KINDS, message: "%{value} is not a valid identity authority" }

  validates :citizen_status,
    allow_blank: true,
    inclusion: { in: CITIZEN_STATUS_KINDS, message: "%{value} is not a valid citizen status" }

  scope :all_under_age_twenty_six, ->{ gt(:'dob' => (TimeKeeper.date_of_record - 26.years))}
  scope :all_over_age_twenty_six,  ->{lte(:'dob' => (TimeKeeper.date_of_record - 26.years))}

  # TODO: Add scope that accepts age range
  scope :all_over_or_equal_age, ->(age) {lte(:'dob' => (TimeKeeper.date_of_record - age.years))}
  scope :all_under_or_equal_age, ->(age) {gte(:'dob' => (TimeKeeper.date_of_record - age.years))}

  alias_method :is_state_resident?, :is_state_resident
  alias_method :is_incarcerated?,   :is_incarcerated

  embeds_one :lawful_presence_determination

  embeds_many :local_residency_responses, class_name:"EventResponse"

  after_initialize :setup_lawful_determination_instance

  def ssn_or_no_ssn
    errors.add(:base, 'Provide SSN or check No SSN') unless ssn.present? || no_ssn == '1'
  end

  def start_residency_verification_process
    notify(RESIDENCY_VERIFICATION_REQUEST_EVENT_NAME, {:person => self.person})
  end

  def setup_lawful_determination_instance
    unless self.lawful_presence_determination.present?
      self.lawful_presence_determination = LawfulPresenceDetermination.new
    end
  end

  def lawful_presence_determination_instance
    setup_lawful_determination_instance
    self.lawful_presence_determination
  end

  def is_aca_enrollment_eligible?
    is_hbx_enrollment_eligible? &&
    Person::ACA_ELIGIBLE_CITIZEN_STATUS_KINDS.include?(citizen_status)
  end

  def is_hbx_enrollment_eligible?
    is_state_resident? && !is_incarcerated?
  end

  def parent
    raise "undefined parent: Person" unless person?
    self.person
  end

  def families
    Family.by_consumerRole(self)
  end

  def phone
    parent.phones.detect { |phone| phone.kind == "home" }
  end

  def email
    parent.emails.detect { |email| email.kind == "home" }
  end

  def home_address
    addresses.detect { |adr| adr.kind == "home" }
  end

  def mailing_address
    addresses.detect { |adr| adr.kind == "mailing" } || home_address
  end

  def billing_address
    addresses.detect { |adr| adr.kind == "billing" } || home_address
  end

  def self.find(consumer_role_id)
    consumer_role_id = BSON::ObjectId.from_string(consumer_role_id) if consumer_role_id.is_a? String
    @person_find = Person.where("consumer_role._id" => consumer_role_id).first.consumer_role unless consumer_role_id.blank?
  end

  def self.all
    Person.all_consumer_roles
  end


  def is_active?
    self.is_active
  end

  def self.naturalization_document_types
    VlpDocument::NATURALIZATION_DOCUMENT_TYPES
  end

  # RIDP and Verify Lawful Presence workflow.  IVL Consumer primary applicant must be in identity_verified state
  # to proceed with application.  Each IVL Consumer enrolled for benefit coverage must (eventually) pass
  def alien_number
    vlp_documents.select{|doc| doc.alien_number.present? }.first.try(:alien_number)
  end

  def i94_number
    vlp_documents.select{|doc| doc.i94_number.present? }.first.try(:i94_number)
  end

  def citizenship_number
    vlp_documents.select{|doc| doc.citizenship_number.present? }.first.try(:citizenship_number)
  end

  def visa_number
    vlp_documents.select{|doc| doc.visa_number.present? }.first.try(:visa_number)
  end

  def sevis_id
    vlp_documents.select{|doc| doc.sevis_id.present? }.first.try(:sevis_id)
  end

  def naturalization_number
    vlp_documents.select{|doc| doc.naturalization_number.present? }.first.try(:naturalization_number)
  end

  def receipt_number
    vlp_documents.select{|doc| doc.receipt_number.present? }.first.try(:receipt_number)
  end

  def passport_number
    vlp_documents.select{|doc| doc.passport_number.present? }.first.try(:passport_number)
  end

  def has_i327?
    vlp_documents.any?{|doc| doc.subject == "I-327 (Reentry Permit)" }
  end

  def has_i571?
    vlp_documents.any?{|doc| doc.subject == "I-551 (Permanent Resident Card)" }
  end

  def has_cert_of_citizenship?
    vlp_documents.any?{|doc| doc.subject == "Certificate of Citizenship" }
  end

  def has_cert_of_naturalization?
    vlp_documents.any?{|doc| doc.subject == "Naturalization Certificate" }
  end

  def has_temp_i551?
    vlp_documents.any?{|doc| doc.subject == "Temporary I-551 Stamp (on passport or I-94)" }
  end

  def has_i94?
    vlp_documents.any?{|doc| doc.subject == "I-94 (Arrival/Departure Record)" || doc.subject == "I-94 (Arrival/Departure Record) in Unexpired Foreign Passport"}
  end

  def has_i20?
    vlp_documents.any?{|doc| doc.subject == "I-20 (Certificate of Eligibility for Nonimmigrant (F-1) Student Status)" }
  end

  def has_ds2019?
    vlp_documents.any?{|doc| doc.subject == "DS2019 (Certificate of Eligibility for Exchange Visitor (J-1) Status)" }
  end

  def i551
    vlp_documents.select{|doc| doc.subject == "I-551 (Permanent Resident Card)" && doc.receipt_number.present? }.first
  end

  def i766
    vlp_documents.select{|doc| doc.subject == "I-766 (Employment Authorization Card)" && doc.receipt_number.present? && doc.expiration_date.present? }.first
  end

  def mac_read_i551
    vlp_documents.select{|doc| doc.subject == "Machine Readable Immigrant Visa (with Temporary I-551 Language)" && doc.issuing_country.present? && doc.passport_number.present? && doc.expiration_date.present? }.first
  end

  def foreign_passport_i94
    vlp_documents.select{|doc| doc.subject == "I-94 (Arrival/Departure Record) in Unexpired Foreign Passport" && doc.issuing_country.present? && doc.passport_number.present? && doc.expiration_date.present? }.first
  end

  def foreign_passport
    vlp_documents.select{|doc| doc.subject == "Unexpired Foreign Passport" && doc.issuing_country.present? && doc.passport_number.present? && doc.expiration_date.present? }.first
  end

  def case1
    vlp_documents.select{|doc| doc.subject == "Other (With Alien Number)" }.first
  end

  def case2
    vlp_documents.select{|doc| doc.subject == "Other (With I-94 Number)" }.first
  end

  ## TODO: Move RIDP to user model
  aasm do
    state :verifications_pending, initial: true
    state :verifications_outstanding
    state :fully_verified

    event :import, :after => [:record_transition, :notify_of_eligibility_change] do
      transitions from: :verifications_pending, to: :fully_verified
      transitions from: :verifications_outstanding, to: :fully_verified
      transitions from: :fully_verified, to: :fully_verified
    end

    event :deny_lawful_presence, :after => [:record_transition, :mark_lp_denied, :notify_of_eligibility_change] do
      transitions from: :verifications_pending, to: :verifications_pending, guard: :residency_pending?
      transitions from: :verifications_pending, to: :verifications_outstanding
      transitions from: :verifications_outstanding, to: :verifications_outstanding
    end

    event :authorize_lawful_presence, :after => [:record_transition, :mark_lp_authorized, :notify_of_eligibility_change] do
      transitions from: :verifications_pending, to: :verifications_pending, guard: :residency_pending?
      transitions from: :verifications_pending, to: :fully_verified, guard: :residency_verified?
      transitions from: :verifications_pending, to: :verifications_outstanding
      transitions from: :verifications_outstanding, to: :verifications_outstanding, guard: :residency_denied?
      transitions from: :verifications_outstanding, to: :fully_verified, guard: :residency_verified?
    end

    event :authorize_residency, :after => [:record_transition, :mark_residency_authorized, :notify_of_eligibility_change] do
      transitions from: :verifications_pending, to: :verifications_pending, guard: :lawful_presence_pending?
      transitions from: :verifications_pending, to: :fully_verified, guard: :lawful_presence_verified?
      transitions from: :verifications_pending, to: :verifications_outstanding
      transitions from: :verifications_outstanding, to: :verifications_outstanding, guard: :lawful_presence_outstanding?
      transitions from: :verifications_outstanding, to: :fully_verified, guard: :lawful_presence_authorized?
    end

    event :deny_residency, :after => [:record_transition, :mark_residency_denied, :notify_of_eligibility_change] do
      transitions from: :verifications_pending, to: :verifications_pending, guard: :lawful_presence_pending?
      transitions from: :verifications_pending, to: :verifications_outstanding
      transitions from: :verifications_outstanding, to: :verifications_outstanding, guard: :lawful_presence_outstanding?
      transitions from: :verifications_outstanding, to: :fully_verified, guard: :lawful_presence_authorized?
    end
  end

  def start_individual_market_eligibility!(requested_start_date)
    if lawful_presence_pending?
      lawful_presence_determination.start_determination_process(requested_start_date)
    end
    if residency_pending?
      start_residency_verification_process
    end
  end

  def update_by_person(*args)
    person.addresses = []
    person.phones = []
    person.emails = []
    person.update_attributes(*args)
  end

  def build_nested_models_for_person
    ["home", "mobile"].each do |kind|
      person.phones.build(kind: kind) if person.phones.select { |phone| phone.kind == kind }.blank?
    end

    Address::KINDS.each do |kind|
      person.addresses.build(kind: kind) if person.addresses.select { |address| address.kind.to_s.downcase == kind }.blank?
    end

    Email::KINDS.each do |kind|
      person.emails.build(kind: kind) if person.emails.select { |email| email.kind == kind }.blank?
    end
  end

  def find_document(subject)
    subject_doc = vlp_documents.detect do |documents|
      documents.subject.eql?(subject)
    end

    subject_doc || vlp_documents.build({subject:subject})
  end

private
  def notify_of_eligibility_change
    CoverageHousehold.update_individual_eligibilities_for(self)
  end

  def mark_residency_denied(*args)
    self.residency_determined_at = TimeKeeper.datetime_of_record
    self.is_state_resident = false
  end

  def mark_residency_authorized(*args)
    self.residency_determined_at = TimeKeeper.datetime_of_record
    self.is_state_resident = true
  end

  def lawful_presence_pending?
    lawful_presence_determination.verification_pending?
  end

  def lawful_presence_outstanding?
    lawful_presence_determination.verification_outstanding?
  end

  def lawful_presence_authorized?
    lawful_presence_determination.verification_successful?
  end

  def residency_pending?
    is_state_resident.nil?
  end

  def residency_denied?
    (!is_state_resident.nil?) && (!is_state_resident)
  end

  def residency_verified?
    is_state_resident?
  end

  def ssn_verified?
    if lawful_presence_determination.vlp_document_id == 'ssa'
      lawful_presence_authorized?
    else
      true
    end
  end

  def citizenship_verified?
    lawful_presence_authorized?
  end

  def indian_conflict?
    citizen_status == "indian_tribe_member"
  end

  def mark_lp_authorized(*args)
    if aasm.current_event == :authorize_lawful_presence!
      lawful_presence_determination.authorize!(*args)
    else
      lawful_presence_determination.authorize(*args)
    end
  end

  def mark_lp_denied(*args)
    if aasm.current_event == :deny_lawful_presence!
      lawful_presence_determination.deny!(*args)
    else
      lawful_presence_determination.deny(*args)
    end
  end

  def record_transition(*args)
    workflow_state_transitions << WorkflowStateTransition.new(
      from_state: aasm.from_state,
      to_state: aasm.to_state
    )
  end

end
