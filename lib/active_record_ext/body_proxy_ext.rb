# Original file path:
# activerecord/lib/active_record/query_cache.rb

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    class BodyProxy # :nodoc:
      def close
        @target.close if @target.respond_to?(:close)
      ensure
        ActiveRecord::Base.connection_id = @connection_id
        ActiveRecord::Base.connection.clear_query_cache
        unless @original_cache_value
          ActiveRecord::Base.connection.disable_query_cache!
        end
        
        # ADD ONE MORE STATEMENT HERE.
        # remove the thread => pool mapping created for this request.
        ActiveRecord::Base.remove_connection
      end
    end
  end
end