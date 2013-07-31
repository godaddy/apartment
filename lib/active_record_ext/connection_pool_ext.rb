# Original file path:
# activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb

if defined?(ActiveRecord)
	
  module ActiveRecord
    module ConnectionAdapters
      class ConnectionHandler

        @@debug = false

        def establish_connection(name, spec)
          thread_id = Thread.current.object_id

          puts "Thread# in establish_connection: #{thread_id}" if @@debug
          puts "Spec.config in establish_connection is: " if @@debug
          puts "#{spec.config}" if @@debug

          # Use, host and database name as the unique key to each connection_pool,
          #   notice we are creating connection pool to each database *server*.
          connection_pool_key = get_connection_pools_key(spec.config)

          # Create one if connection_pool to this database server hasn't been created yet.
          @connection_pools[connection_pool_key] ||= ConnectionAdapters::ConnectionPool.new(spec)

          if @class_to_pool[name].nil?
            @class_to_pool[name] = {thread_id => @connection_pools[connection_pool_key]}
          else
            @class_to_pool[name][thread_id] = @connection_pools[connection_pool_key]
          end
        end

        # remove_connection will remove the thread => pool mapping, and actually kill the connection_pool
        #   if no other thread is using it.
        def remove_connection(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in remove_connection is #{thread_id}" if @@debug

          unless @class_to_pool[klass.name] == nil
            pool = @class_to_pool[klass.name].delete(thread_id)
            unless  pool.nil?
              puts "[REMOVE MAPPING] Remove connection mapping: #{klass.name} => #{thread_id} => #{pool.spec.config}" if @@debug
              puts "@class_to_pool[#{klass.name}].length is : #{@class_to_pool[klass.name].length}" if @@debug

              # Actually kill the connection pool if no other thread is using it.
              kill_connection_pool(pool) unless @class_to_pool[klass.name].has_value? pool

              pool.spec.config
            end
          end
        end

        def retrieve_connection_pool(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in retrive_conenction_pool #{thread_id}" if @@debug

          pool = @class_to_pool[klass.name].try :fetch, thread_id, nil

          return pool if pool
          return nil if ActiveRecord::Base == klass

          # Even if the it goes to the superclass, 
          #   the logic will only look in the corresponding thread_id.
          retrieve_connection_pool klass.superclass

        rescue Exception => e
          puts "Current Thread is is: #{thread_id}"
          #puts "@class_to_pool:"
          #p @class_to_pool
          puts "----------------------------"
          puts "klass name is #{klass.name}"
          raise e
        end

        # ONLY remove the thread => pool mapping.
        def remove_thread_pool_mapping(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in remove_thread_pool_mapping is #{thread_id}" if @@debug
          @class_to_pool[klass.name].delete(thread_id) unless @class_to_pool[klass.name] == nil
          puts "[REMOVE MAPPING] @class_to_pool[#{klass.name}].length is : #{@class_to_pool[klass.name].length}"# if @@debug
        end

        private
        
        # Delete the pool from connection_pools and disconnect it.  
        def kill_connection_pool(pool)
          puts "[KILL] Kill connection_pool: #{pool.spec.config}" if @@debug
          @connection_pools.delete get_connection_pools_key(pool.spec.config)
          pool.automatic_reconnect = false
          pool.disconnect!
        end

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



