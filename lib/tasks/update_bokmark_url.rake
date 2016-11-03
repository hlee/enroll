namespace :update do
  desc "update user's bookmark_url by consumer_role or employee_role"
  task :user_bookmark_url => :environment do 
    person_count = Person.count
    offset_count = 0
    limit_count = 500
    processed_count = 0

    while (offset_count < person_count) do
      puts "offset_count: #{offset_count}"
      Person.limit(limit_count).offset(offset_count).each do |person|
        if person.user.present?
          if person.consumer_role.present? && person.consumer_role.bookmark_url.present?
            person.set_bookmark_url_by_role!('consumer_role', person.consumer_role.bookmark_url)
          end
          if person.employee_roles.present? && person.employee_roles.last.try(:bookmark_url).try(:present?)
            person.set_bookmark_url_by_role!('employee_role', person.employee_roles.last.bookmark_url)
          end
          if person.employer_staff_roles.present? && person.employer_staff_roles.last.try(:bookmark_url).try(:present?)
            person.set_bookmark_url_by_role!('employer_staff_role', person.employer_staff_roles.last.bookmark_url)
          end
          processed_count += 1
        end
      end
      offset_count += limit_count
    end

    puts "updated #{processed_count} users for bookmark_url"
  end
end
