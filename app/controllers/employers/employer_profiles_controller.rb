class Employers::EmployerProfilesController < ApplicationController

  before_action :find_employer, only: [:show, :show_profile, :destroy, :inbox,
                                       :bulk_employee_upload, :bulk_employee_upload_form]

  before_action :check_admin_staff_role, only: [:index]
  before_action :check_employer_staff_role, only: [:new]

  layout "two_column", except: [:new]

  def index
    if params[:broker_agency_id].blank?
      @q = params.permit(:q)[:q]
      @orgs = Organization.search(@q).exists(employer_profile: true)
    else
      @orgs = Organization.by_broker_agency_profile(BSON::ObjectId.from_string(params[:broker_agency_id]))

    end

    if @q.blank?
      @page_alphabets = page_alphabets(@orgs, "legal_name")
      page_no = cur_page_no(@page_alphabets.first)
      @organizations = @orgs.where("legal_name" => /^#{page_no}/i)
      @employer_profiles = @organizations.map {|o| o.employer_profile}
    else
      @employer_profiles = @orgs.map {|o| o.employer_profile}
    end

    @profile = find_mailbox_provider
  end

  def welcome
  end

  def search
    @employer_profile = Forms::EmployerCandidate.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  def match
    @employer_candidate = Forms::EmployerCandidate.new(params.require(:employer_profile))
    if @employer_candidate.valid?
      found_employer = @employer_candidate.match_employer
      unless params["create_employer"].present?
        if found_employer.present?
          @employer_profile = found_employer
          respond_to do |format|
            format.js { render 'match' }
            format.html { render 'match' }
          end
        else
          respond_to do |format|
            format.js { render 'no_match' }
            format.html { render 'no_match' }
          end
        end
      else
        params.permit!
        build_organization
        @employer_profile.attributes = params[:employer_profile]
        @organization.save(validate: false)
        build_office_location
        respond_to do |format|
          format.js { render "edit" }
          format.html { render "edit" }
        end
      end
    else
      @employer_profile = @employer_candidate
      respond_to do |format|
        format.js { render 'search' }
        format.html { render 'search' }
      end
    end
  end

  def my_account
  end

  def show
   @tab = params['tab']
   if params[:q] || params[:page] || params[:commit] || params[:status]
     paginate_employees
   else
      case @tab
      when 'benefits'
        @current_plan_year = @employer_profile.published_plan_year
        @plan_years = @employer_profile.plan_years.order(id: :desc)
      when 'documents'
      when 'employees'
        paginate_employees
      when 'brokers'
        @broker_agency_accounts = @employer_profile.broker_agency_accounts
      when 'inbox'
      else
        @current_plan_year = @employer_profile.published_plan_year
        if @current_plan_year.present?
          @additional_required_participants_count = @current_plan_year.additional_required_participants_count
        end
        if @current_plan_year.present?
          #FIXME commeted out for performance test
          enrollments = @current_plan_year.hbx_enrollments
          if enrollments.size < 100
            @premium_amt_total = enrollments.map(&:total_premium).sum
            @employee_cost_total = enrollments.map(&:total_employee_cost).sum
            @employer_contribution_total = enrollments.map(&:total_employer_contribution).sum
          end
        end
      end
    end
  end

  def show_profile
    @tab ||= params[:tab]
    if @tab == 'benefits'
      @current_plan_year = @employer_profile.published_plan_year
      @plan_years = @employer_profile.plan_years.order(id: :desc)
    elsif @tab == 'employees'
      paginate_employees

    elsif @tab == 'families'
     #families defined as employee_roles.each { |ee| ee.person.primary_family }
     paginate_families
   elsif @tab == "inbox"
     @folder = params[:folder] || 'Inbox'
     @sent_box = false
     respond_to do |format|
       format.js { render 'employers/employer_profiles/inbox' }
     end
   end

    end


  def new
    @organization = Forms::EmployerProfile.new
  end

  def edit
    @organization = Organization.find(params[:id])
    @employer_profile = @organization.employer_profile
    @employer = @employer_profile.match_employer(current_user)
  end

  def create
    params.permit!
    @organization = Forms::EmployerProfile.new(params[:organization])
    if @organization.save(current_user)
      @person = current_user.person
      create_sso_account(current_user, current_user.person, 15, "employer") do
        redirect_to employers_employer_profile_path(@organization.employer_profile, tab: 'home')
      end
    else
      render action: "new"
    end
  end

  def update
    sanitize_employer_profile_params
    params.permit!
    @organization = Organization.find(params[:id])

    #save duplicate office locations as json in case we need to refresh
    @organization_dup = @organization.office_locations.as_json

    @employer_profile = @organization.employer_profile
    @employer = @employer_profile.match_employer(current_user)
    if current_user.has_employer_staff_role? && @employer_profile.staff_roles.include?(current_user.person)
      @organization.assign_attributes(organization_profile_params)

      #clear office_locations, don't worry, we will recreate
      @organization.assign_attributes(:office_locations => [])
      @organization.save(validate: false)

      if @organization.update_attributes(employer_profile_params) and @employer.update_attributes(employer_params)
        flash[:notice] = 'Employer successfully Updated.'
        redirect_to edit_employers_employer_profile_path(@organization)
      else

        #in case there was an error, reload from saved json
        @organization.assign_attributes(:office_locations => @organization_dup)
        @organization.save(validate: false)
        #@organization.reload
        flash[:notice] = 'Employer information not saved.'
        redirect_to edit_employers_employer_profile_path(@organization)
      end
    else
      flash[:error] = 'You do not have permissions to update the details'
      redirect_to edit_employers_employer_profile_path(@employer_profile)
    end
  end

  def inbox
    @folder = params[:folder] || 'Inbox'
    @sent_box = false
    respond_to do |format|
      format.js { render 'inbox' }
      format.html { render 'inbox' }
    end
  end

  def consumer_override
    session[:person_id] = params['person_id']
    redirect_to family_account_path
  end

  def bulk_employee_upload_form

  end

  def bulk_employee_upload
    file = params.require(:file)
    @census_employee_import = CensusEmployeeImport.new({file:file, employer_profile:@employer_profile})
    begin
    if @census_employee_import.save
      redirect_to "/employers/employer_profiles/#{@employer_profile.id}?employer_profile_id=#{@employer_profile.id}&tab=employees", :notice=>"#{@census_employee_import.length} records uploaded from CSV"
    else
      render "employers/employer_profiles/employee_csv_upload_errors"
    end
    rescue Exception => e
      @census_employee_import.errors.add(:base, e.message)
      render "employers/employer_profiles/employee_csv_upload_errors"
    end


  end

  private
    def paginate_employees
      status_params = params.permit(:id, :status, :search)
      @status = status_params[:status] || 'active'
      @search = status_params[:search] || false
      #@avaliable_employee_names ||= @employer_profile.census_employees.sorted.map(&:full_name).map(&:strip).map {|name| name.squeeze(" ")}.uniq
      #@avaliable_employee_names ||= @employer_profile.census_employees.where(last_name: => /^#{page_no}/i).limit(20).map(&:full_name).map(&:strip).map {|name| name.squeeze(" ")}.uniq

      census_employees = case @status
      when 'terminated'
        @employer_profile.census_employees.terminated.sorted
      when 'all'
        @employer_profile.census_employees.sorted
      else
        @employer_profile.census_employees.active.sorted
      end
      census_employees = census_employees.search_by(params.slice(:employee_name))
      @page_alphabets = page_alphabets(census_employees, "last_name")

      if params[:page].present?
        page_no = cur_page_no(@page_alphabets.first)
        @census_employees = census_employees.where("last_name" => /^#{page_no}/i).page(params[:pagina])
        #@avaliable_employee_names ||= @census_employees.limit(20).map(&:full_name).map(&:strip).map {|name| name.squeeze(" ")}.uniq
      else
        @total_census_employees_quantity = census_employees.count
        @census_employees = census_employees.limit(20).to_a
        #@avaliable_employee_names ||= @census_employees.map(&:full_name).map(&:strip).map {|name| name.squeeze(" ")}.uniq
      end
    end

    def paginate_families
      #FIXME add paginate
      @employees = @employer_profile.employee_roles.to_a
    end

    def check_employer_staff_role
      if current_user.has_employer_staff_role?
        redirect_to employers_employer_profile_path(:id => current_user.person.employer_staff_roles.first.employer_profile_id, :tab => "home")
      end
    end

   def find_mailbox_provider
     hbx_staff = current_user.person.hbx_staff_role
     if hbx_staff
       profile = current_user.person.hbx_staff_role.hbx_profile
     else
       broker_id = current_user.person.broker_role.broker_agency_profile_id.to_s
       profile = BrokerAgencyProfile.find(broker_id)
     end
     return profile
   end

    def check_admin_staff_role
      if current_user.has_hbx_staff_role? || current_user.has_broker_agency_staff_role? || current_user.has_broker_role?
      elsif current_user.has_employer_staff_role?
        redirect_to employers_employer_profile_path(:id => current_user.person.employer_staff_roles.first.employer_profile_id)
      else
        redirect_to new_employers_employer_profile_path
      end
    end

    def find_employer
      id_params = params.permit(:id, :employer_profile_id)
      id = id_params[:id] || id_params[:employer_profile_id]
      @employer_profile = EmployerProfile.find(id)
    end

    def organization_profile_params
      params.require(:organization).permit(
        :id,
        :employer_profile_attributes => [:legal_name, :entity_kind, :dba]
      )
    end

    def employer_profile_params
      params.require(:organization).permit(
        :employer_profile_attributes => [ :entity_kind, :dba, :legal_name],
        :office_locations_attributes => [
          :address_attributes => [:kind, :address_1, :address_2, :city, :state, :zip],
          :phone_attributes => [:kind, :area_code, :number, :extension],
          :email_attributes => [:kind, :address]
        ]
      )
    end

    def sanitize_employer_profile_params
      params[:organization][:office_locations_attributes].each do |key, location|
        params[:organization][:office_locations_attributes].delete(key) unless location['address_attributes']
        location.delete('phone_attributes') if (location['phone_attributes'].present? and location['phone_attributes']['number'].blank?)
      end
    end

    def build_organization
      @organization = Organization.new
      @employer_profile = @organization.build_employer_profile
    end

    def build_employer_profile_params
      build_organization
      build_office_location
    end

    def build_office_location
      @organization.office_locations.build unless @organization.office_locations.present?
      office_location = @organization.office_locations.first
      office_location.build_address unless office_location.address.present?
      office_location.build_phone unless office_location.phone.present?
      @organization
    end

    def employer_params
      params.permit(:first_name, :last_name, :dob)
    end
end
