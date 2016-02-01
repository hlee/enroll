module Analytics
  class Dimensions::Monthly
    include Mongoid::Document

      field :title, type: String
      field :site,  type: String, default: "dchbx"
      field :topic, type: String
      field :date,  type: Date
      field :month, type: Integer
      field :year,  type: Integer

      field :d1,  type: Integer, default: 0
      field :d2,  type: Integer, default: 0
      field :d3,  type: Integer, default: 0
      field :d4,  type: Integer, default: 0
      field :d5,  type: Integer, default: 0
      field :d6,  type: Integer, default: 0
      field :d7,  type: Integer, default: 0
      field :d8,  type: Integer, default: 0
      field :d9,  type: Integer, default: 0

      field :d10, type: Integer, default: 0
      field :d11, type: Integer, default: 0
      field :d12, type: Integer, default: 0
      field :d13, type: Integer, default: 0
      field :d14, type: Integer, default: 0
      field :d15, type: Integer, default: 0
      field :d16, type: Integer, default: 0
      field :d17, type: Integer, default: 0
      field :d18, type: Integer, default: 0
      field :d19, type: Integer, default: 0

      field :d20, type: Integer, default: 0
      field :d21, type: Integer, default: 0
      field :d22, type: Integer, default: 0
      field :d23, type: Integer, default: 0
      field :d24, type: Integer, default: 0
      field :d25, type: Integer, default: 0
      field :d26, type: Integer, default: 0
      field :d27, type: Integer, default: 0
      field :d28, type: Integer, default: 0
      field :d29, type: Integer, default: 0

      field :d30, type: Integer, default: 0
      field :d31, type: Integer, default: 0

      index({site: 1, topic: 1, month: 1, year: 1})

      validates_presence_of :site, :topic, :date, :month, :year

      after_initialize :pre_allocate_document

      def increment(new_date)
        day_of_month = new_date.day

        # Use the Mongoid increment (inc) function
        inc(("d" + day_of_month.to_s).to_sym => 1)
        self
      end

      def self.options
        (1..31).map do |k|
          "d#{k}"
        end
      end

      def sum
        (1..31).map do |k|
          date = Date.new(year, month, k) rescue false
          if date
            eval('d' + k.to_s)
          end
        end.compact
      end

      def sum_for_stock
        (1..31).map do |k|
          date = Date.new(year, month, k) rescue false
          if date
            [date.to_datetime.to_i*1000, self.public_send("d#{k}")]
          end
        end.compact
      end

      def amount_for_drilldown
        (1..31).map do |k|
          date = Date.new(year, month, k) rescue false
          if date
            ["d#{k}", self.public_send("d#{k}")]
          end
        end.compact
      end

      def amount
        (1..31).reduce(0) do |sum, k|
          sum + self.public_send("d#{k}")
        end
      end

    private
      def pre_allocate_document
        self.month = date.month
        self.year  = date.year
      end

  end
end
