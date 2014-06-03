if defined?(ActiveRecord)

  ActiveRecord.module_eval do
    ActiveRecord::ConnectionAdapters.module_eval do
      ActiveRecord::ConnectionAdapters::ConnectionHandler.class_eval do

        # Reuse or create a connection pool.
        # Copied from ActiveRecord and modified to reuse an existing pool if there is one.
        def establish_connection(owner, spec)
          @class_to_pool.clear
          raise RuntimeError, "Anonymous class is not allowed." unless owner.name
          owner_to_pool[owner.name] ||= connection_pool(spec)
        end

        # Remove connection will only remove the owner to pool mapping,
        # but will NOT kill the pool.
        def remove_connection(owner)
          if pool = owner_to_pool.delete(owner.name)
            @class_to_pool.clear
            pool.spec.config
          end
        end

        private

        # Get the key of connection_pools based on the input database config.
        def get_connection_pools_key(config)
          {
            host:     config[:host],
            database: config[:database]
          }
        end

        # Return a (possibly pre-existing) connection pool based on a database config.
        def connection_pool(spec)
          connection_pool_key = get_connection_pools_key(spec.config)
          @connection_pools ||= {}
          @connection_pools[connection_pool_key] ||= ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec)
        end

      end
    end
  end

end
