module PortalHeaderHelper
  def portal_display_name(controller)
    if current_user.nil?
      "Welcome to the District's Health Insurance Marketplace"
    elsif current_user.try(:has_hbx_staff_role?)
      link_to "#{image_tag 'icons/icon-exchange-admin.png'} &nbsp; I'm an Admin".html_safe, exchanges_hbx_profiles_root_path
    elsif current_user.person.try(:broker_role)
      link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Broker".html_safe, broker_agencies_profile_path(id: current_user.person.broker_role.broker_agency_profile_id) 
    elsif current_user.try(:person).try(:csr_role) || current_user.try(:person).try(:assister_role)
      link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Trained Expert".html_safe, home_exchanges_agents_path
    elsif current_user.try(:has_employee_role?)
        "#{image_tag 'icons/icon-individual.png'} &nbsp; I'm an Employee".html_safe
    elsif (controller_path.include?("insured") && current_user.try(:has_consumer_role?))
        "#{image_tag 'icons/icon-family.png'} &nbsp; Individual and Family".html_safe
    elsif current_user.try(:has_broker_agency_staff_role?)
      link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Broker".html_safe, broker_agencies_profile_path(id: current_user.person.broker_role.broker_agency_profile_id) 
    elsif current_user.try(:has_employer_staff_role?)
      "#{image_tag 'icons/icon-business-owner.png'} &nbsp; I'm an Employer".html_safe
    else
      "Welcome to the District's Health Insurance Marketplace"
    end
  end

  # def enrollment_name
  #   begin
  #     person = Person.find(session[:person_id])
  #     name=  'Assisting: ' + person.full_name
  #   rescue
  #     name = ''
  #   end
  # end
  # def agent_header
  #   header_text = "<div style='display:inline-block'>&nbsp; I'm a Trained Expert</div>"
  #   link_to "#{image_tag 'icons/icon-expert.png'}#{header_text}".html_safe, home_exchanges_agents_path
  # end
  #
  # def hbx_staff_header
  #   header_text = "<div style='display:inline-block; white-space: nowrap; position: relative; top: -5px;'>&nbsp; I'm an Admin</div>"
  #   link_to "#{image_tag 'icons/icon-exchange-admin.png', style: 'position: relative; top: -8px; left: 10px; margin-right: 5px;'} #{header_text}".html_safe, exchanges_hbx_profiles_root_path, style: 'padding: 16px 20px 0 0;'
  # end
  #
  # def broker_header
  #   header_text = "<div style='display:inline-block white-space: nowrap; position: relative; top: -5px;'>&nbsp; I'm a Broker</div>"
  #   link_to "#{image_tag 'icons/icon-expert.png', style: 'position: relative; top: -8px; left: 10px; margin-right: 5px;'} #{header_text}".html_safe, broker_agencies_profile_path(id: current_user.person.broker_role.broker_agency_profile_id), style: 'padding: 16px 20px 0 0;'
  # end
end
