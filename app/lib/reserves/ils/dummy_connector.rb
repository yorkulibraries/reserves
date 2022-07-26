module Reserves
  module Ils
    class DummyConnector < Connector
      def initialize()
      end

      def reserve_an_item(item_id,reserve_location, course_id, user_id)
        return true
      end
    end
  end

end
