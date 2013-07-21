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
          
          @connection_pools[spec] ||= ConnectionAdapters::ConnectionPool.new(spec)
  
          unless @class_to_pool[thread_id] == nil
            @class_to_pool[thread_id].merge!({name => @connection_pools[spec]})
          else
            @class_to_pool[thread_id] = {name => @connection_pools[spec]} 
          end
  
        end
  
        def remove_connection(klass)

          thread_id = Thread.current.object_id
          puts "Thread# in remove_connection is #{thread_id}" if @@debug
  
          unless @class_to_pool[thread_id] == nil 
  
            pool = @class_to_pool[thread_id].delete(klass.name)
            return nil unless pool
    
            used_by_other_threads = false
            # Check if pool exist in other thread's klass_pool_map.
            @class_to_pool.each_value do |klass_pool_map|
              if klass_pool_map.has_value? pool
                used_by_other_threads = true
              end
            end
    
            unless used_by_other_threads
              puts "[REMOVE] @class_to_pool[#{thread_id}][#{klass.name}]"
              @connection_pools.delete pool.spec
              pool.automatic_reconnect = false
              pool.disconnect!
            end
            
            # Return the config should be done in both cases.
            pool.spec.config
          end

        end
  
        def retrieve_connection_pool(klass)
        
          thread_id = Thread.current.object_id
          puts "Thread# in retrive_conenction_pool #{thread_id}" if @@debug
  
          pool = @class_to_pool[thread_id][klass.name]
  
          return pool if pool
          return nil if ActiveRecord::Base == klass
  
          # Even if the it goes to the superclass, 
          #   the logic will only look in the corresponding thread_id.
          retrieve_connection_pool klass.superclass
        end

      end
    end
  end

end