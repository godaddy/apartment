
# Original file path:
# activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb

if defined?(ActiveRecord)
	
  module ActiveRecord
    module ConnectionAdapters
      class ConnectionHandler

        @@debug = false
        @@thread_first = true

        def establish_connection(name, spec)

          thread_id = Thread.current.object_id
          puts "Thread# in establish_connection: #{thread_id}" if @@debug
  
          puts "Spec.config in establish_connection is: " if @@debug
          puts "#{spec.config}" if @@debug
          
          @connection_pools[spec] ||= ConnectionAdapters::ConnectionPool.new(spec)
  
          if @@thread_first
            unless @class_to_pool[thread_id] == nil
              @class_to_pool[thread_id][name] = @connection_pools[spec]
            else
              @class_to_pool[thread_id] = {name => @connection_pools[spec]} 
            end
          else
            unless @class_to_pool[name] == nil
              @class_to_pool[name][thread_id] = @connection_pools[spec]
            else
              @class_to_pool[name] = {thread_id => @connection_pools[spec]}
            end
          end

        end
  
        def remove_connection(klass)

          thread_id = Thread.current.object_id
          puts "Thread# in remove_connection is #{thread_id}" if @@debug
  
          if @@thread_first
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
                puts "[REMOVE] @class_to_pool[#{thread_id}][#{klass.name}]" if @@debug
                @connection_pools.delete pool.spec
                pool.automatic_reconnect = false
                pool.disconnect!
              end
              
              # Return the config should be done in both cases.
              pool.spec.config
            end
          else

            unless @class_to_pool[klass.name] == nil
  
              pool = @class_to_pool[klass.name].delete(thread_id)
              return nil if pool==nil
  
              if @class_to_pool[klass.name].empty?
                puts "[REMOVE] @class_to_pool[#{klass.name}][#{thread_id}]" if @@debug
                @connection_pools.delete pool.spec
                pool.automatic_reconnect = false
                pool.disconnect!
              end
  
              # Return the config should be done in both cases.
              pool.spec.config
            end

          end
        end
  
        def retrieve_connection_pool(klass)
          thread_id = Thread.current.object_id
          puts "Thread# in retrive_conenction_pool #{thread_id}" if @@debug

          if @@thread_first
            pool = @class_to_pool[thread_id][klass.name]
            
            return pool if pool
            return nil if ActiveRecord::Base == klass
            
            # Even if the it goes to the superclass, 
            #   the logic will only look in the corresponding thread_id.
            retrieve_connection_pool klass.superclass
          else
            unless @class_to_pool[klass.name].nil?
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



