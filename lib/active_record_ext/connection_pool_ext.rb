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
          connection_pool_key = {:host => spec.config[:host], 
                                 :database => spec.config[:database]}

          # Create one if connection_pool to this database server hasn't been created yet.
          if @connection_pools[connection_pool_key].nil?
            @connection_pools[connection_pool_key] = ConnectionAdapters::ConnectionPool.new(spec)
          end

          unless @class_to_pool[name] == nil
            @class_to_pool[name][thread_id] = @connection_pools[connection_pool_key]
          else
            @class_to_pool[name] = {thread_id => @connection_pools[connection_pool_key]}
          end
        end

        # Notice remove_connection does NOT actually disconnect connection pool.
        #  Since we build the connection pool to a database SERVER, we want to keep it open for later use.
        #  Thus, remove_connection here only removes the thread => coon_pool mapping.
        def remove_connection(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in remove_connection is #{thread_id}" if @@debug
          unless @class_to_pool[klass.name] == nil
            pool = @class_to_pool[klass.name].delete(thread_id)
            unless  pool.nil?
              puts "[REMOVE] Remove connection mapping: #{klass.name} => #{thread_id} => #{pool.spec.config}" if @@debug
              puts "@class_to_pool[#{klass.name}].length is : #{@class_to_pool[klass.name].length}" if @@debug
              pool.spec.config
            end
          end
        end

        def retrieve_connection_pool(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in retrive_conenction_pool #{thread_id}" if @@debug

          unless @class_to_pool[klass.name].nil?

            # Here, only mapping is deleted, but no actual pool is disconnected.
            #   The reason is that we want to keep that pool since it is connect to db server, not a specific db.
            pool = @class_to_pool[klass.name][thread_id]

            return pool if pool != nil
            return nil if ActiveRecord::Base == klass

            # Even if the it goes to the superclass, 
            #   the logic will only look in the corresponding thread_id.
            retrieve_connection_pool klass.superclass
          else
            return nil if ActiveRecord::Base == klass
            retrieve_connection_pool klass.superclass
          end

        rescue Exception => e
          puts "Current Thread is is: #{thread_id}"
          #puts "@class_to_pool:"
          #p @class_to_pool
          puts "----------------------------"
          puts "klass name is #{klass.name}"
          raise e
        end

      end
    end
  end

end



