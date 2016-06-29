class HbxAdmin
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps

  $months_array = Date::ABBR_MONTHNAMES.compact

  class << self

    def build_household_level_aptc_csr_data(family, hbxs=nil, max_aptc=nil, csr_percentage=nil, applied_aptc_array=nil,  member_ids=nil)
      max_aptc_vals             = build_max_aptc_values(family, max_aptc)
      csr_percentage_vals       = build_csr_percentage_values(family, csr_percentage)
      avalaible_aptc_vals       = build_avalaible_aptc_values(family, hbxs, applied_aptc_array, max_aptc, member_ids)   
      return { "max_aptc" => max_aptc_vals, "available_aptc" => avalaible_aptc_vals, "csr_percentage" => csr_percentage_vals}
    end

    def build_avalaible_aptc_values(family, hbxs, applied_aptc_array=nil, max_aptc=nil,  member_ids=nil)
      available_aptc_hash = Hash.new
      max_aptc_vals             = build_max_aptc_values(family, max_aptc)
      total_aptc_applied_vals_for_household = Hash[$months_array.map { |x| [x, '%.2f' % 0.0] }] # Initialize a Hash for monthly values.
      hbxs.each do |hbx|
        aptc_applied_vals_for_enrollment = build_aptc_applied_values_for_enrollment(family, hbx, applied_aptc_array)
        total_aptc_applied_vals_for_household  = total_aptc_applied_vals_for_household.merge(aptc_applied_vals_for_enrollment) { |k, a_value, b_value| a_value.to_f + b_value.to_f } # Adding values of two similar hashes. 
      end
      #subtract each value of aptc_applied hash from the max_aptc hash to get APTC Available.
      max_aptc_vals.merge(total_aptc_applied_vals_for_household) { |k, a_value, b_value| '%.2f' % (a_value.to_f - b_value.to_f) }
    end

    def build_household_members(family)
      build_individuals_covered_array(family, $months_array)
    end

    def build_enrollments_data(family, hbxs, applied_aptc_array=nil, max_aptc=nil, csr_percentage=nil, member_ids=nil)
      enrollments_data = Hash.new
      hbxs.each do |hbx|
        enrollments_data[hbx.id] = self.build_enrollment_level_aptc_csr_data(family, hbx, applied_aptc_array, max_aptc, csr_percentage)
      end
      return enrollments_data
    end

    def build_enrollment_level_aptc_csr_data(family, hbx, applied_aptc_array=nil, max_aptc=nil, csr_percentage=nil,  member_ids=nil) #TODO: Last param remove 
      aptc_applied_vals             = build_aptc_applied_values_for_enrollment(family, hbx, applied_aptc_array)
      aptc_applied_per_member_vals  = build_aptc_applied_per_member_values_for_enrollment(family, hbx, aptc_applied_vals, applied_aptc_array)
      return { "aptc_applied" => aptc_applied_vals, "aptc_applied_per_member" => aptc_applied_per_member_vals }
    end

    def build_plan_premium_hash_for_enrollments(hbxs)
      plan_premium_hash = Hash.new
      hbxs.each do |hbx| 
        plan_premium_hash[hbx.id.to_s] = (hbx.try(:total_premium) || false)
      end
      return plan_premium_hash
    end


    def build_aptc_applied_values_for_enrollment(family, current_hbx, applied_aptc_array=nil)
      # Get all aptc enrollments (coverage selected, terminated or cancelled) that have the same hbx_id as current_hbx. 
      # These are the dups of the current enrollment that were saved when APTC values were updated.
      enrollments_with_same_hbx_id = family.active_household.hbx_enrollments.active.with_aptc.by_year(TimeKeeper.date_of_record.year).by_hbx_id(current_hbx.hbx_id) 
      enrollments_with_same_hbx_id.sort! {|a, b| a.effective_on <=> b.effective_on}

      aptc_applied_hash = Hash.new
      $months_array.each_with_index do |month, ind|
        enrollments_with_same_hbx_id.each do |hbx_iter|
          update_aptc_applied_hash_for_month(aptc_applied_hash, current_hbx, month, hbx_iter, family, applied_aptc_array)
        end
      end
      return aptc_applied_hash
    end

    def update_aptc_applied_hash_for_month(aptc_applied_hash, current_hbx, month, hbx_iter, family, applied_aptc_array=nil)
      first_of_month_num_current_year = first_of_month_converter(month)
      applied_aptc = 0.0 
      if applied_aptc_array.present?
        if first_of_month_num_current_year >= TimeKeeper.datetime_of_record
          applied_aptc_array.each do |one_hbx|
            applied_aptc = one_hbx[1]["aptc_applied"].to_f if current_hbx.id.to_s == one_hbx[1]["hbx_id"].gsub("aptc_applied_","")
          end
        else
          applied_aptc = hbx_iter.applied_aptc_amount.to_f
        end
      else
        applied_aptc = hbx_iter.applied_aptc_amount.to_f
      end

      first_of_month_num_current_year = first_of_month_converter(month)
      if first_of_month_num_current_year >= hbx_iter.effective_on
        aptc_applied_hash.store(month, '%.2f' % applied_aptc)
      else
        aptc_applied_hash.store(month, '%.2f' % 0.00) if aptc_applied_hash[month].blank? #dont mess with the past values
      end  
    end

    def build_aptc_applied_per_member_values_for_enrollment(family, current_hbx, aptc_applied_vals, applied_aptc_array=nil)
      aptc_ratio_by_member = family.active_household.latest_active_tax_household.aptc_ratio_by_member
      aptc_applied_per_member = Hash.new
      current_hbx.hbx_enrollment_members.each do |hem|
        ratio_for_this_member = aptc_ratio_by_member[hem.applicant_id.to_s]
        aptc_applied_member_vals = aptc_applied_vals.inject({}) { |h, (k, v)| h[k] = '%.2f' % (v.to_f*ratio_for_this_member); h }
        aptc_applied_per_member[hem.person.id.to_s] =  aptc_applied_member_vals
      end
      aptc_applied_per_member
    end
    

    def build_max_aptc_values(family, max_aptc=nil)
      max_aptc_hash = Hash.new
      eligibility_determinations = family.active_household.latest_active_tax_household.eligibility_determinations
      eligibility_determinations.sort! {|a, b| a.determined_on <=> b.determined_on}
      $months_array.each_with_index do |month, ind|
        # iterate over all the EligibilityDeterminations and store the correct max_aptc value for each month. Account for any monthly change in Eligibility Determination.
        eligibility_determinations.each do |ed|
          update_max_aptc_hash_for_month(max_aptc_hash, month, ed, max_aptc)
        end  
      end
      return max_aptc_hash
    end

    def update_max_aptc_hash_for_month(max_aptc_hash, month, ed, max_aptc=nil)
      first_of_month_num_current_year = first_of_month_converter(month)
      max_aptc_value = ""
      if max_aptc.present?
        # this is when we check available aptc. We only want to update the current and future fields with the updated value.
        if first_of_month_num_current_year >= TimeKeeper.datetime_of_record
          max_aptc_value = max_aptc
        else
          # leave past values as-is
          max_aptc_value = ed.max_aptc.to_f
        end 
      else
        max_aptc_value = ed.max_aptc.to_f
      end
      # Check if  'month' >= EligibilityDetermination.determined_on date?
      if first_of_month_num_current_year >= ed.determined_on
        # assign that month with aptc_max value from this ed (EligibilityDetermination)
        max_aptc_hash.store(month, '%.2f' % max_aptc_value)
      else
        # update max_aptc value for that month as a "---"
        max_aptc_hash.store(month, '%.2f' % 0) if max_aptc_hash[month].blank?
      end  
    end

    def build_csr_percentage_values(family, csr_percentage=nil)
      csr_percentage_hash = Hash.new
      eligibility_determinations = family.active_household.latest_active_tax_household.eligibility_determinations
      eligibility_determinations.sort! {|a, b| a.determined_on <=> b.determined_on}
      $months_array.each_with_index do |month, ind|
        eligibility_determinations.each do |ed|
          update_csr_percentages_hash_for_month(csr_percentage_hash, month, ed, csr_percentage)
        end
      end
      return csr_percentage_hash
    end

    def update_csr_percentages_hash_for_month(csr_percentage_hash, month, ed, csr_percentage=nil)
      first_of_month_num_current_year = first_of_month_converter(month)
      csr_percentage_value = ""
      #csr_percentage_value = csr_percentage.present? ? csr_percentage : ed.csr_percent_as_integer
      if csr_percentage.present?
        # this is when we check available aptc. We only want to update the current and future fields with the updated value.
        if first_of_month_num_current_year >= TimeKeeper.datetime_of_record
          csr_percentage_value = csr_percentage
        else
          # leave past values as-is
          csr_percentage_value = ed.csr_percent_as_integer
        end 
      else
        csr_percentage_value = ed.csr_percent_as_integer
      end
      # Check if  'month' >= EligibilityDetermination.determined_on date?
      if first_of_month_num_current_year >= ed.determined_on
        # assign that month with csr_percent value from this ed (EligibilityDetermination)
        csr_percentage_hash.store(month, csr_percentage_value)
      else
        # update csr_percent value for that month as a "-"
        csr_percentage_hash.store(month, 0) if csr_percentage_hash[month].blank?
      end  
    end

    def first_of_month_converter(month)
      month_num = Date::ABBR_MONTHNAMES.index(month.capitalize || month) # coverts Month name to Month Integer : "jan" -> 1
      current_year = TimeKeeper.date_of_record.year
      first_of_month_num_current_year = Date.parse("#{current_year}-#{month_num}-01")
      return first_of_month_num_current_year
    end  


    def calculate_slcsp_value(family, member_ids=nil)
      benefit_sponsorship = HbxProfile.current_hbx.benefit_sponsorship
      eligibility_determinations = family.active_household.latest_active_tax_household.eligibility_determinations
      benefit_coverage_period = benefit_sponsorship.benefit_coverage_periods.detect {|bcp| bcp.contains?(TimeKeeper.datetime_of_record)}
      slcsp = benefit_coverage_period.second_lowest_cost_silver_plan
      if member_ids.present?
        aptc_members = family.active_household.latest_active_tax_household.tax_household_members.select {|m| member_ids.include?(m.person.id.to_s) }
      else
        aptc_members = family.active_household.latest_active_tax_household.aptc_members
      end
      cost = aptc_members.map do |member|
        slcsp.premium_for(TimeKeeper.datetime_of_record, member.age_on_effective_date)
      end.inject(:+) || 0       
      return '%.2f' % cost
    end


    def build_individuals_covered_array(family, months_array)
      individuals_covered_array = Array.new
      eligibility_determinations = family.active_household.latest_active_tax_household.eligibility_determinations
      family.family_members.each_with_index do |one_member, index|
          covered_hash = Hash.new
            months_array.each_with_index do |month, ind|
                eligibility_determinations.each do |ed|
                  first_of_month_num_current_year = first_of_month_converter(month)
                  if first_of_month_num_current_year >= ed.determined_on
                    covered_hash.store(month, true)
                  else
                    #check if present/future data? #if current/present?
                    if first_of_month_num_current_year >= TimeKeeper.datetime_of_record
                      covered_hash.store(month, false)
                    #if past data?
                    else
                      covered_hash.store(month, false) if covered_hash[month].blank?
                    end
                  end 
                end
            end
           individuals_covered_array << {one_member.person.id.to_s => covered_hash} 
      end
      return individuals_covered_array
    end


    def build_eligible_members(family, member_ids=nil)
      return member_ids if member_ids.present?
      eligible_members = Array.new
      tax_household_members = family.active_household.latest_active_tax_household_with_year(TimeKeeper.date_of_record.year).try(:tax_household_members)
      return [] if tax_household_members.nil?
      tax_household_members.each do |member|
        if member.is_ia_eligible
          eligible_members << member.person.id.to_s
        end
      end
      return eligible_members
    end


    def build_aptc_per_enrollment(hbxs)
      aptc_per_enrollment = Hash.new
      hbxs.each do |hbx|
        plan_name         = Plan.where(id: hbx.plan_id).first.name
        hbx_applied_aptc  = hbx.applied_aptc_amount.to_f
        aptc_per_enrollment[hbx.id.to_s] = [hbx_applied_aptc, plan_name]
      end
      aptc_per_enrollment  
    end


    def build_current_aptc_applied_hash(hbxs, applied_aptcs_array=nil)
      current_aptc_applied_hash = Hash.new
      hbxs.each do |hbx|
        if applied_aptcs_array.present?
          applied_aptcs_array.each do |app_aptc|
            current_aptc_applied_hash[hbx.id.to_s] =  '%.2f' % app_aptc[1]["aptc_applied"].to_f if hbx.id.to_s == app_aptc[1]["hbx_id"].gsub("aptc_applied_","") 
          end          
        else
          current_aptc_applied_hash[hbx.id.to_s] = (hbx.applied_aptc_amount || 0)
        end
      end
      return current_aptc_applied_hash  
    end

    def redetermine_eligibility_with_updated_values(family, params)
      eligibility_redetermination_result = false
      max_aptc = family.active_household.latest_active_tax_household.latest_eligibility_determination.max_aptc
      csr_percent_as_integer = family.active_household.latest_active_tax_household.latest_eligibility_determination.csr_percent_as_integer 
      existing_latest_eligibility_determination = family.active_household.latest_active_tax_household.latest_eligibility_determination
      latest_active_tax_household = family.active_household.latest_active_tax_household

      if !(params[:max_aptc].to_f == max_aptc && params[:csr_percentage].to_i == csr_percent_as_integer) # IF NOT
        eligibility_redetermination_result = true
        # If max_aptc / csr percent is updated, create a new eligibility_determination with a new "determined_on" timestamp and the corresponsing csr/aptc update.
        latest_active_tax_household.eligibility_determinations.build({"determined_at"                 => TimeKeeper.datetime_of_record, 
                                                                      "determined_on"                 => TimeKeeper.datetime_of_record, 
                                                                      "csr_eligibility_kind"          => existing_latest_eligibility_determination.csr_eligibility_kind, 
                                                                      "premium_credit_strategy_kind"  => existing_latest_eligibility_determination.premium_credit_strategy_kind, 
                                                                      "csr_percent_as_integer"        => params[:csr_percentage].to_i, 
                                                                      "max_aptc"                      => params[:max_aptc].to_f, 
                                                                      "benchmark_plan_id"             => existing_latest_eligibility_determination.benchmark_plan_id,
                                                                      "e_pdc_id"                      => existing_latest_eligibility_determination.e_pdc_id,
                                                                      "source"                        => "Admin"  
                                                                      }).save!
      end
      eligibility_redetermination_result
    end

    def update_aptc_applied_for_enrollments(params)
      enrollment_update_result = false
      # For every HbxEnrollment, if Applied APTC was updated, clone a new enrtollment with the new Applied APTC and make the current one inactive.
      family = Family.find(params[:person][:family_id])
      active_aptc_hbxs = family.active_household.hbx_enrollments_with_aptc_by_year(params[:year].to_i)
      current_datetime = TimeKeeper.datetime_of_record
      params.each do |key, aptc_value|
        if key.include?('aptc_applied_')
          hbx_id = key.sub("aptc_applied_", "")
          updated_aptc_value = aptc_value.to_f
          actual_aptc_value = HbxEnrollment.find(hbx_id).applied_aptc_amount.to_f
          # Only create enrollments if the APTC values were updated.
          if actual_aptc_value != updated_aptc_value
              enrollment_update_result = true
              original_hbx = HbxEnrollment.find(hbx_id)
              aptc_ratio_by_member = family.active_household.latest_active_tax_household.aptc_ratio_by_member
              
              # Duplicate Enrollment
              duplicate_hbx = original_hbx.dup
              duplicate_hbx.created_at = current_datetime
              duplicate_hbx.updated_at = current_datetime
              duplicate_hbx.effective_on = find_enrollment_effective_on_date(current_datetime) # Populate the effective_on date based on the 15th day rule.

              # Duplicate all Enrollment Members
              duplicate_hbx.hbx_enrollment_members = original_hbx.hbx_enrollment_members.collect {|hem| hem.dup}
              duplicate_hbx.hbx_enrollment_members.each{|hem| hem.updated_at = current_datetime}

              # Update Applied APTC on the enrolllment level.
              duplicate_hbx.applied_aptc_amount = updated_aptc_value
              
              # Update the correct breakdown of Applied APTC on the individual level.
              duplicate_hbx.hbx_enrollment_members.each do |hem|
                aptc_pct_for_member = aptc_ratio_by_member[hem.applicant_id.to_s]
                hem.applied_aptc_amount = aptc_pct_for_member * updated_aptc_value
              end

              family.active_household.hbx_enrollments << duplicate_hbx
              family.save

              # Cancel or Terminate Coverage.
              if original_hbx.can_terminate_coverage?
                original_hbx.terminate_coverage!
              else
                original_hbx.cancel_coverage!
              end
          end

        end 
      end
      enrollment_update_result  
    end  
  
    def find_enrollment_effective_on_date(hbx_created_datetime)
      offset_month = TimeKeeper.datetime_of_record.day <= 15 ? 1 : 2
      return DateTime.new(TimeKeeper.datetime_of_record.year, TimeKeeper.datetime_of_record.month + offset_month, 1)
    end

    def build_error_messages(max_aptc, csr_percentage, applied_aptcs_array)
      sum_of_all_applied = 0.0
      aptc_errors = Hash.new
      applied_aptcs_array.each {|hbx| sum_of_all_applied += hbx[1]["aptc_applied"].to_f} if applied_aptcs_array.present?
      if max_aptc == "NaN"
        aptc_errors["MAX_APTC_NON_NUMERIC"] = "Max APTC needs to be a numeric value."
      else
        aptc_errors["MAX_APTC_TOO_SMALL"] = "Max APTC should be greater than or equal to the sum of APTC Applied for all enrollments." if sum_of_all_applied.to_f > max_aptc.to_f if applied_aptcs_array.present?
      end
      return aptc_errors
    end

  end #  end of class << self
end # end of class HbxAdmin