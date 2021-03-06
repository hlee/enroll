module RuleSet
  module HbxEnrollment
    class IndividualMarketVerification
      attr_reader :hbx_enrollment

      def initialize(h_enrollment)
        @hbx_enrollment = h_enrollment
      end

      def applicable?
        hbx_enrollment.currently_active? && (!hbx_enrollment.benefit_sponsored?)
      end

      def roles_for_determination
        hbx_enrollment.hbx_enrollment_members.map(&:person).map(&:consumer_role)
      end

      def determine_next_state
        return(:move_to_pending!) if roles_for_determination.any?(&:verifications_pending?)
        return(:move_to_contingent!) if roles_for_determination.any?(&:verifications_outstanding?)
        :move_to_enrolled!
      end
    end
  end
end
