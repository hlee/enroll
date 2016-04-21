class GeneralAgencies::ProfilesController < ApplicationController
  skip_before_action :require_login, only: [:new_agency, :new_agency_staff, :create]
  skip_before_action :authenticate_me!, only: [:new_agency, :new_agency_staff, :create]
  before_action :check_admin_staff_role, only: [:index]
  before_action :find_hbx_profile, only: [:index]
  before_action :find_general_agency_profile, only: [:show, :edit, :update, :employers, :families, :staffs, :agency_messages]
  before_action :find_general_agency_staff, only: [:edit_staff, :update_staff]
  before_action :check_general_agency_staff_role, only: [:new]

  def new
    @organization = ::Forms::GeneralAgencyProfile.new
  end

  def index
    @general_agency_profiles = GeneralAgencyProfile.all
  end

  def new_agency
    @organization = ::Forms::GeneralAgencyProfile.new
  end

  def new_agency_staff
    @organization = ::Forms::GeneralAgencyProfile.new
  end

  def create
    @organization = ::Forms::GeneralAgencyProfile.new(general_agency_profile_params)
    @organization.languages_spoken = params.require(:organization)[:languages_spoken].reject!(&:empty?) if params.require(:organization)[:languages_spoken].present?
    if @organization.save
      flash[:notice] = "Your registration has been submitted. A response will be sent to the email address you provided once your application is reviewed."
      redirect_to general_agency_registration_path
    else
      render "new_agency"
    end
  end

  def show
    @provider = current_user.person
    @staff_role = current_user.has_general_agency_staff_role?
    @id=params[:id]
  end

  def employers
    @employers = @general_agency_profile.employer_clients || []
  end

  def families
    @families = @general_agency_profile.family_clients
  end

  def staffs
    @staffs = @general_agency_profile.general_agency_staff_roles
  end

  def edit_staff
    respond_to do |format|
      format.js
      format.html
    end
  end

  def update_staff
    if params['approve']
      @staff.approve!
      @staff.general_agency_profile.approve! if @staff.general_agency_profile.may_approve?
      flash[:notice] = "Staff approved."
    elsif params['deny']
      @staff .deny!
      flash[:notice] = "Staff denied."
    elsif params['decertify']
      @staff.decertify!
      flash[:notice] = "Staff decertified."
    elsif params['accept']
      @staff.general_agency_accept!
      flash[:notice] = "Staff accepted successfully."
    elsif params['decline']
      @staff.general_agency_decline!
      flash[:notice] = "Staff declined."
    elsif params['terminate']
      @staff.general_agency_terminate!
      flash[:notice] = "Staff terminated."
    end
    send_secure_message_to_general_agency(@staff) if @staff.agency_pending?

    redirect_to general_agencies_profile_path(@staff.general_agency_profile)
  end

  def messages
    @sent_box = true
    @provider = current_user.person
  end

  def agency_messages
    @sent_box = true
  end

  def inbox
    @sent_box = true
    id = params["id"]||params['profile_id']
    @general_agency_provider = GeneralAgencyProfile.find(id)
    @folder = (params[:folder] || 'Inbox').capitalize
    if current_user.person._id.to_s == id
      @provider = current_user.person
    else
      @provider = @general_agency_provider
    end
  end

  private
  def find_general_agency_profile
    @general_agency_profile = GeneralAgencyProfile.find(params[:id])
  end

  def find_hbx_profile
    @profile = current_user.person.hbx_staff_role.hbx_profile
  end

  def find_general_agency_staff
    @staff = GeneralAgencyStaffRole.find(params[:id])
  end

  def check_admin_staff_role
    if current_user.has_hbx_staff_role? || current_user.has_csr_role?
    elsif current_user.has_general_agency_staff_role?
      redirect_to general_agencies_profile_path(:id => current_user.person.general_agency_staff_roles.first.general_agency_profile_id)
    else
      redirect_to new_broker_agencies_profile_path
    end
  end

  def check_general_agency_staff_role
    if current_user.has_general_agency_staff_role?
      redirect_to general_agencies_profile_path(id: current_user.person.general_agency_staff_roles.last.general_agency_profile_id)
    else
      flash[:notice] = "You don't have a General Agency Profile associated with your Account!! Please register your General Agency first."
    end
  end

  def general_agency_profile_params
    params.require(:organization).permit(
      :first_name, :last_name, :dob, :email, :npn, :legal_name, :dba,
      :fein, :entity_kind, :home_page, :market_kind, :languages_spoken,
      :working_hours, :accept_new_clients, :general_agency_profile_id, :applicant_type,
      :office_locations_attributes => [
        :address_attributes => [:kind, :address_1, :address_2, :city, :state, :zip],
        :phone_attributes => [:kind, :area_code, :number, :extension]
      ]
    )
  end

  def send_secure_message_to_general_agency(staff_role)
    hbx_admin = HbxProfile.all.first
    general_agency = staff_role.general_agency_profile

    subject = "Received new general agency - #{staff_role.person.full_name}"
    body = "<br><p>Following are staff details<br>Staff Name : #{staff_role.person.full_name}<br>Staff NPN  : #{staff_role.npn}</p>"
    secure_message(hbx_admin, general_agency, subject, body)
  end
end
