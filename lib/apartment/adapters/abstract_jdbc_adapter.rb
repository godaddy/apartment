=begin

!!!WARNING!!!
This file has not been updated to work with multiple database servers.
!!!WARNING!!!


module Apartment
  module Adapters
    class AbstractJDBCAdapter < AbstractAdapter

    protected

      #   Return a new config that is multi-tenanted
      #
      def multi_tenantify(database)
        @config.clone.tap do |config|
          config[:url] = "#{config[:url].gsub(/(\S+)\/.+$/, '\1')}/#{environmentify(database)}"
        end
      end
    private

      def rescue_from
        ActiveRecord::JDBCError
      end
    end
  end
end

=end