class Insured::ConsumerRolesController < ApplicationController
  include ApplicationHelper
  include VlpDoc

  before_action :check_consumer_role, only: [:search]
  before_action :find_consumer_role, only: [:edit, :update]
  #before_action :authorize_for, except: [:edit, :update]

  def privacy
    set_current_person
    redirect_to @person.consumer_role.bookmark_url || family_account_path  if @person.try(:consumer_role?)
  end

  def search
    @no_previous_button = true
    @no_save_button = true
    if params[:aqhp].present?
      session[:individual_assistance_path] = true
    else
      session.delete(:individual_assistance_path)
    end
    @person = Forms::ConsumerCandidate.new
    respond_to do |format|
      format.html
    end
  end

  def match
    @no_save_button = true
    @person_params = params.require(:person).merge({user_id: current_user.id})
    @consumer_candidate = Forms::ConsumerCandidate.new(@person_params)
    @person = @consumer_candidate
    respond_to do |format|
      if @consumer_candidate.valid?
        idp_search_result = nil
        if current_user.idp_verified?
          idp_search_result = :not_found
        else
          idp_search_result = IdpAccountManager.check_existing_account(@consumer_candidate)
        end
        case idp_search_result
        when :service_unavailable
          format.html { render 'shared/account_lookup_service_unavailable' }
        when :too_many_matches
          format.html { redirect_to SamlInformation.account_conflict_url }
        when :existing_account
          format.html { redirect_to SamlInformation.account_recovery_url }
        else 
          unless params[:persisted] == "true"
            @employee_candidate = Forms::EmployeeCandidate.new(@person_params)

            if @employee_candidate.valid?
              found_census_employees = @employee_candidate.match_census_employees
              @employment_relationships = Factories::EmploymentRelationshipFactory.build(@employee_candidate, found_census_employees.first)
              if @employment_relationships.present?
                format.html { render 'insured/employee_roles/match' }
              end
            end
          end

          found_person = @consumer_candidate.match_person
          if found_person.present?
            if found_person.try(:consumer_role)
               session[:already_has_consumer_role] = true
               session[:person_id] = found_person.id
            end
            format.html { render 'match' }
          else
            format.html { render 'no_match' }
          end
        end
      else
        format.html { render 'search' }
      end
    end
  end

  def create
    if !session[:already_has_consumer_role] == true
      @consumer_role = Factories::EnrollmentFactory.construct_consumer_role(params.permit!, actual_user)
      if @consumer_role.present?
        @person = @consumer_role.person
      else
        # not logging error because error was logged in construct_consumer_role
        render file: 'public/500.html', status: 500
        return
      end
    else
      @person= Person.find(session[:person_id])
      @person.user = current_user
      @person.save
    end
    is_assisted = session["individual_assistance_path"]
    role_for_user = (is_assisted) ? "assisted_individual" : "individual"
    create_sso_account(current_user, @person, 15, role_for_user) do
      respond_to do |format|
        format.html {
          if is_assisted
            @person.primary_family.update_attribute(:e_case_id, "curam_landing_for#{@person.id}") if @person.primary_family
            redirect_to navigate_to_assistance_saml_index_path
          else
            if session[:already_has_consumer_role] == true
              redirect_to family_account_path
            else
              redirect_to :action => "edit", :id => @consumer_role.id
            end
          end
        }
      end
    end
  end

  def immigration_document_options
    if params[:target_type] == "Person"
      @target = Person.find(params[:target_id])
    elsif params[:target_type] == "Forms::FamilyMember"
      if params[:target_id].present?
        @target = Forms::FamilyMember.find(params[:target_id])
      else
        @target = Forms::FamilyMember.new
      end
    end
    @vlp_doc_target = params[:vlp_doc_target]
  end

  def edit
    #authorize @consumer_role, :edit?
    set_consumer_bookmark_url
    @consumer_role.build_nested_models_for_person
    @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@consumer_role)
  end

  def update
    #authorize @consumer_role, :update?
    save_and_exit =  params['exit_after_method'] == 'true'

    if update_vlp_documents(@consumer_role, 'person') and @consumer_role.update_by_person(params.require(:person).permit(*person_parameters_list))
      if save_and_exit
        respond_to do |format|
          format.html {redirect_to destroy_user_session_path}
        end
      else
        redirect_to ridp_agreement_insured_consumer_role_index_path
      end
    else
      if save_and_exit
        respond_to do |format|
          format.html {redirect_to destroy_user_session_path}
        end
      else
        @consumer_role.build_nested_models_for_person
        @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@consumer_role)
        respond_to do |format|
          format.html { render "edit" }
        end
      end
    end
  end

  def ridp_agreement
    if session[:original_application_type] == 'paper'
      set_current_person
      redirect_to insured_family_members_path(:consumer_role_id => @person.consumer_role.id)
      return
    else
      set_consumer_bookmark_url
    end
  end

  private
  def person_parameters_list
    [
      { :addresses_attributes => [:kind, :address_1, :address_2, :city, :state, :zip] },
      { :phones_attributes => [:kind, :full_phone_number] },
      { :emails_attributes => [:kind, :address] },
      { :consumer_role_attributes => [:contact_method, :language_preference]},
      :first_name,
      :last_name,
      :middle_name,
      :name_pfx,
      :name_sfx,
      :dob,
      :ssn,
      :no_ssn,
      :gender,
      :language_code,
      :is_incarcerated,
      :is_disabled,
      :race,
      :is_consumer_role,
      {:ethnicity => []},
      :us_citizen,
      :naturalized_citizen,
      :eligible_immigration_status,
      :indian_tribe_member,
      :tribal_id,
      :no_dc_address,
      :no_dc_address_reason
    ]
  end

  def find_consumer_role
    @consumer_role = ConsumerRole.find(params.require(:id))
  end

  def check_consumer_role
    set_current_person
    if @person.try(:has_active_consumer_role?)
      redirect_to @person.consumer_role.bookmark_url || family_account_path

    else
      current_user.last_portal_visited = search_insured_consumer_role_index_path
      current_user.save!
      # render 'privacy'
    end
  end
end
