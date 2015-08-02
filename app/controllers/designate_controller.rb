class DesignateController < ApplicationController
  def new
    initialize_common_vars
    emp_role_id = params.require(:employee_role_id)
    @employee_role = @person.employee_roles.detect { |emp_role| emp_role.id.to_s == emp_role_id.to_s }

    # for individual
    @employer_profile_for_individual = Organization.where(legal_name: "Global Systems For Individual").last.employer_profile
    #for dental
    @employer_profile_for_dental = Organization.where(legal_name: "Global Systems For Dental").last.employer_profile

    @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
  end

  def create
    initialize_common_vars
    employer_profile_id = params.require(:eligibility_reasons)
    emp_role_id = params.require(:employee_role_id)
    @employee_role = @person.employee_roles.detect{|emp_role| emp_role.employer_profile_id.to_s == employer_profile_id.to_s }

    if @employee_role.blank?
      @employer_profile = EmployerProfile.find(employer_profile_id)
      census_employee = @employer_profile.census_employees.where(ssn: @person.ssn).last
      #FIXME may need to create this employee_roles other proper place
      #since there is not linked employee
      if census_employee.present?
      @employee_role = @person.employee_roles.create(
        employer_profile_id: @employer_profile.id,
        census_employee_id: census_employee.id,
        benefit_group_id: census_employee.active_benefit_group_assignment.benefit_group_id,
        hired_on: census_employee.hired_on)
      else
        @employee_role = @person.employee_roles.create(
          employer_profile_id: @employer_profile.id,
          benefit_group_id: @employer_profile.plan_years.last.benefit_groups.last.id,
          hired_on: Date.today.at_beginning_of_month
        )
      end
    end
    #hbx_enrollment = HbxEnrollment.new_from(
    #  employee_role: @employee_role,
    #  coverage_household: @coverage_household,
    #  benefit_group: @employee_role.benefit_group)
    @change_plan = params[:change_plan].present? ? params[:change_plan] : ''

    redirect_to group_selection_new_path(person_id: @person.id, employee_role_id: @employee_role.id, emp_role_id: emp_role_id, change_plan: @change_plan)
  end

  private
  def initialize_common_vars
    person_id = params.require(:person_id)
    @person = Person.find(person_id)
    @family = @person.primary_family
    @coverage_household = @family.active_household.immediate_family_coverage_household
  end
end
