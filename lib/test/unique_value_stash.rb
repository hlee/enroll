module UniqueValueStash
  class UniqueValues 
    def initialize
      @unique_values = {}
    end
    def number digits=9, key=nil
      random_value = (0.1 + 0.9*rand)* (10**digits)
      digit_string = random_value.to_i.to_s
      @unique_values[key] = digit_string if key
      digit_string
    end
    def find key
      @unique_values[key]
    end
    def adult_dob key=nil
      unique_date = "0#{number 1}/0#{number 1}/#{1950+rand(60)}"
      @unique_values[key] = unique_date if key
      unique_date
    end
    def last_name key=nil
      unique_last_name = "Wei#{rand(100000)}"
      @unique_values[key] = unique_last_name if key 
      unique_last_name   
    end
    def email key=nil
      unique_email = "Trey#{rand(100000)}@example.com"
      @unique_values[key] = unique_email if key
      unique_email
    end
    def ssn key=nil
      number 9, key
    end
    def fein key=nil
      number 9, key
    end   
  end
end