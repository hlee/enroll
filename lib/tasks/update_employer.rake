namespace :update_employer do
  desc "update planyear for employer profile so that employer is valid"
  task :plan_year => :environment do 
    eps = EmployerProfile.all.select {|ep| !ep.valid?}
    eps.each do |ep|
      ep.plan_years.each do |plan_year|
        puts "."
        if !plan_year.valid? && plan_year.errors.full_messages.include?("Open enrollment end on open enrollment must end on or before the 10th day of the month prior to effective date") && plan_year.start_on < TimeKeeper.date_of_record
          puts "X"
          plan_year.open_enrollment_end_on = plan_year.start_on - 1.month + Settings.aca.shop_market.open_enrollment.monthly_end_on - 1.days
          plan_year.open_enrollment_start_on = plan_year.open_enrollment_end_on - 6.days
          plan_year.save
        end
      end
    end
  end
end
