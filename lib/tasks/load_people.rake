namespace :seed do
  desc "Load the people data"
  task :people => :environment do
    Person.delete_all
    file = File.open("db/seedfiles/people.json", "r")
    contents = file.read
    file.close
    data = JSON.load(contents)
    puts "Loading #{data.count} people."
    num_success = data.reduce(0) do |acc, pd|
      person = Person.create(pd)
      person.valid? ? acc + 1 : acc
    end
    puts "Loaded #{num_success} people successfully."
  end

  desc "Load the family data"
  task :families => :environment do
    Family.delete_all
    file = File.open("db/seedfiles/families.json", "r")
    contents = file.read
    file.close
    data = JSON.load(contents)
    puts "Loading #{data.count} families."
    num_success = data.reduce(0) do |acc, pd|
      family = Family.create!(pd)
      family.households.first.coverage_households.first.coverage_household_members.each_with_index do |fm, index|
        fm.update_attributes(applicant_id: pd["households"].first["coverage_households"].first["coverage_household_members"][index]["applicant_id"])
      end
      family.valid? ? acc + 1 : acc
    end
    puts "Loaded #{num_success} families successfully."
  end
end
