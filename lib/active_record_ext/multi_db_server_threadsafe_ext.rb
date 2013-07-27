# Original file path:
# activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb

if defined?(ActiveRecord)
	
  module ActiveRecord
    module ConnectionAdapters
      class ConnectionHandler

        @@debug = false
        @@sleep_time = 0.2

        def establish_connection(name, spec)
          thread_id = Thread.current.object_id

          puts "Thread# in establish_connection: #{thread_id}" if @@debug
          puts "Spec.config in establish_connection is: " #if @@debug
          puts "#{spec.config}" #if @@debug

          @connection_pools[spec.config] = @connection_pools[spec.config] || ConnectionAdapters::ConnectionPool.new(spec)

          # Generate an array with first value being the thread id, and second value being time_stamp.
          key = [thread_id, time_stamp]

          unless @class_to_pool[name] == nil
            @class_to_pool[name][key] = @connection_pools[spec.config]
          else
            @class_to_pool[name] = {key => @connection_pools[spec.config]}
          end
        rescue RuntimeError => e
          # If catch an hash iteration error, pause for @@sleep_time seconds.
          if e.message == "can't add a new key into hash during iteration"
            sleep @@sleep_time
            puts "[RESCUE] Catch error: #{e.message}"
            self.establish_connection(name, spec)
          else
            raise e
          end
        end
  
        def remove_connection(klass)

          thread_id = Thread.current.object_id
          puts "Thread# in remove_connection is #{thread_id}" if @@debug

          unless @class_to_pool[klass.name] == nil

            # Iterate through each key, value pair of this class's value (key => coon)
            # If this coon has current thread as first part of its key, remove this coon.
            # If not, but this coon is established more than 10 seconds ago, remove this coon. * So for sure this thread is not currently being used.
            @class_to_pool[klass.name].each do |thread_time, conn|
              if thread_time[0] == thread_id
                pool = @class_to_pool[klass.name].delete(thread_time)
                removed_config = pool.spec.config
                remove_conn pool
              else
                if (Time.now.to_i-thread_time[1]) > 10
                  pool = @class_to_pool[klass.name].delete(thread_time)
                  remove_conn pool
                end
              end
            end

            # Return the config should be done in both cases.
            removed_config if defined? (removed_config)
          end
        end

        # Delete current coon from connection_pools and disconnect it.  
        def remove_conn(pool)
          puts "[REMOVE] Remove connection: #{pool.spec.config}" if @@debug
          @connection_pools.delete pool.spec.config
          pool.automatic_reconnect = false
          pool.disconnect!
        end

        def retrieve_connection_pool(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in retrive_conenction_pool #{thread_id}" if @@debug

          unless @class_to_pool[klass.name].nil?
            pool = nil

            @class_to_pool[klass.name].each do |thread_time, coon|
              if thread_time[0] == thread_id
                pool = coon
                break
              end
            end 

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

        # Return the unix time stamp.
        def time_stamp
          Time.now.to_i
        end

      end
    end
  end

end



