=begin

# Original file path:
# activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb

if defined?(ActiveRecord)
	
  module ActiveRecord
    module ConnectionAdapters
      class ConnectionHandler

        @@debug = false

        def establish_connection(name, spec)
          puts "Spec.config in establish_connection is: " if @@debug
          puts "#{spec.config}" if @@debug

          # Use, host and database name as the unique key to each connection_pool,
          #   notice we are creating connection pool to each database *server*.
          connection_pool_key = get_connection_pools_key(spec.config)

          # Create one if connection_pool to this database server hasn't been created yet.
          @connection_pools[connection_pool_key] ||= ConnectionAdapters::ConnectionPool.new(spec)
          @class_to_pool[name] = @connection_pools[connection_pool_key]
        end

        # Remove connection will only remove the class to pool mapping, 
        #   but will NOT kill the pool.
        def remove_connection(klass)
          pool = @class_to_pool.delete(klass.name)
          return nil unless pool
          pool.spec.config
        end

        private

        # Get the key of connection_pools based on the input database config.
        def get_connection_pools_key(config)
          {
            :host => config[:host], 
            :database => config[:database]
          }
        end

      end
    end
  end

end

=end

