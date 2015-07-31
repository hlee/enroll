class DesignateController < ApplicationController
  def create
    person_id = params.require(:person_id)
    emp_role_id = params.require(:employee_role_id)
    employer_profile_id = params.require(:eligibility_reasons)
    @person = Person.find(person_id)
    @family = @person.primary_family
    @coverage_household = @family.active_household.immediate_family_coverage_household

    @employee_role = @person.employee_roles.detect{|emp_role| emp_role.employer_profile_id.to_s == employer_profile_id.to_s }
    if @employee_role.blank?
      @employer_profile = EmployerProfile.find(employer_profile_id)
      census_employee = @employer_profile.census_employees.where(ssn: @person.ssn).last
      #FIXME may need to create this employee_roles other proper place
      #since there is not linked employee
      @employee_role = @person.employee_roles.create(
        employer_profile_id: @employer_profile.id,
        census_employee_id: census_employee.id,
        benefit_group_id: census_employee.active_benefit_group_assignment.benefit_group_id,
        hired_on: census_employee.hired_on)
    end
    hbx_enrollment = HbxEnrollment.new_from(
      employee_role: @employee_role,
      coverage_household: @coverage_household,
      benefit_group: @employee_role.benefit_group)

    if hbx_enrollment.save
      redirect_to insured_plan_shopping_path(:id => hbx_enrollment.id)
    else
      redirect_to group_selection_new_path(person_id: @person.id, employee_role_id: emp_role_id)
    end
  end
end
