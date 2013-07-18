require 'active_record'

module Apartment
  module Adapters
    class AbstractAdapter

      #   @constructor
      #   @param {Hash} config Database config
      #   ------------------------------------------------------
      #   Basically, config is the info in database in yml file.
      #   Example of what @config might be: 
      #           {:adapter=>"mysql2", 
      #            :encoding=>"utf8", 
      #            :reconnect=>false, 
      #            :database=>"spree", 
      #            :pool=>5, 
      #            :username=>"root", 
      #            :password=>nil, 
      #            :host=>"127.0.0.1", 
      #            :port=>3306}
      def initialize(config)
        @config = config
      end

      #   Create a new database, import schema, seed if appropriate
      #
      #   @param {hash} database_info, :database, :host, :default_db
      #   -------------------------------------------------------
      #   Will call create_database function in this file to do the actual job.
      def create(database_info)

        puts "Creating databse with db_info:"
        puts "#{database_info}"

        create_database(database_info)

        database_config = database_info.clone.tap {|config| config[:default_db] = nil}
        
        # Swich to created new db and do stuff, like seed, then switch back to cur db.
        process(database_config) do
          import_database_schema

          # Seed data if appropriate
          seed_data if Apartment.seed_after_create

          yield if block_given?
        end

        puts "Creating finished, now in database:"
        puts "#{current_database}"
      end

      #   Get the current database name
      #
      #   @return {hash} current database's config, :database, :host
      #   ---------------------------------------
      #   See file lib/apartment.rb
      #   The body is equivalent as
      #
      #   ActiveRecord::Base.connection.current_database
      #
      #   If you do not set any :connection_class
      def current_database
        Apartment.connection.instance_variable_get(:@config).clone
      end

      # return {string}, name of the current database
      def current_database_name
        Apartment.connection.current_database
      end

      #   Note alias_method here doesn't work with inheritence apparently ??
      #
      def current
        current_database
      end

      #   TODO: MODIFY DROP!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #   Drop the database
      #
      #   @param {String} database Database name
      #   --------------------------------------
      #   See file lib/apartment.rb
      #   The body is equivalent as
      #
      #   ActiveRecord::Base.connection.execute("DROP DATABASE #{environmentify(database)}" )
      #
      #   If you do not set any :connection_class
      def drop(database)
        # Apartment.connection.drop_database   note that drop_database will not throw an exception, so manually execute
        Apartment.connection.execute("DROP DATABASE #{environmentify(database)}" )

      rescue *rescuable_exceptions
        raise DatabaseNotFound, "The database #{environmentify(database)} cannot be found"
      end

      #   Connect to db, do your biz, switch back to previous db
      #
      #   @param {hash} database_config, :database, :host
      #
      def process(database_config = nil)
        current_db = current_database

        switch(database_config)

        yield if block_given?

      ensure
        switch(current_db) rescue reset
      end

      #   Establish a new connection for each specific excluded model
      #   ------------------------------------------------------------
      #   Because a model will inherit from ActiveRecord::Base, the model will
      #   have a method establish_connection defined in AR::Base class.
      #
      #   The logic of this method is that for those exluded_models, connection to 
      #   default/common db first, then do the business.
      def process_excluded_models
        # All other models will shared a connection (at Apartment.connection_class) and we can modify at will
        Apartment.excluded_models.each do |excluded_model|
          excluded_model.constantize.establish_connection @config
        end
      end

      #   Reset the database connection to the default
      #   --------------------------------------
      #   See file lib/apartment.rb
      #   The body is equivalent as
      #
      #   ActiveRecord::Base.establish_connection @config
      #
      #   If you do not set any :connection_class
      def reset
        Apartment.establish_connection @config
      end

      #   Switch to new connection (or schema if appopriate)
      #
      #   @param {hash} database_config, :database, :host
      #   ------------------------------------------------
      #   Some doc on .tap method, it is interesting.
      #   http://apidock.com/rails/Object/tap
      def switch(database_config = nil)
        # Just connect to default db and return

        return reset if database_config.nil?

        connect_to_new(database_config).tap do
          ActiveRecord::Base.connection.clear_query_cache
        end
      end

      #   Load the rails seed file into the db
      #   ------------------------------------------------
      #   Explaination on silence_stream:
      #   http://apidock.com/rails/Kernel/silence_stream
      def seed_data
        silence_stream(STDOUT){ load_or_abort("#{Rails.root}/db/seeds.rb") } # Don't log the output of seeding the db
      end
      alias_method :seed, :seed_data

    protected

      #   Create the database
      #
      #   @param {hash} database_info, :database, :host, :default_server
      #   --------------------------------------
      #   See file lib/apartment.rb
      #   The body is equivalent as
      #
      #   ActiveRecord::Base.connection.create_database( environmentify(database) )
      #
      #   If you do not set any :connection_class
      def create_database(database_info)

        default_database_config = database_info.clone.tap do |config|
          config[:database] = database_info[:default_db]          
        end

        process(default_database_config) do
          Apartment.connection.create_database( environmentify(database_info[:database]) )
        end

      rescue *rescuable_exceptions
        raise DatabaseExists, "The database #{environmentify(database_info[:database])} already exists."
      end

      #   Connect to new database
      #
      #   @param {hash} database_config, :database, :host
      #   -----------------------------------------------
      #   See file lib/apartment.rb
      def connect_to_new(database_config)
        Apartment.establish_connection multi_tenantify(database_config)
        Apartment.connection.active?   # call active? to manually check if this connection is valid

      rescue *rescuable_exceptions
        raise DatabaseNotFound, "The database #{environmentify(database_config[:database])} cannot be found."
      end

      #   Prepend the environment if configured and the environment isn't already there
      #
      #   @param {String} database Database name
      #   @return {String} database name with Rails environment *optionally* prepended
      #
      def environmentify(database)
        unless database.include?(Rails.env)
          if Apartment.prepend_environment
            "#{Rails.env}_#{database}"
          elsif Apartment.append_environment
            "#{database}_#{Rails.env}"
          else
            database
          end
        else
          database
        end
      end

      #   Import the database schema
      #
      def import_database_schema
        ActiveRecord::Schema.verbose = false    # do not log schema load output.

        load_or_abort(Apartment.database_schema_file) if Apartment.database_schema_file
      end

      #   Return a new config that is multi-tenanted
      #   
      #   NOTICE: This method could become dummy 
      #             if database_config is the full configuration.
      #   --------------------------------------------------
      #   MAGIC IS HERE:
      #   this method will update the @config with point to correct database
      #   by updating the hash.
      def multi_tenantify(database_config)
        @config.clone.tap do |config|
          config[:database] = environmentify(database_config[:database])
          config[:host] = database_config[:host] unless database_config[:host].nil?
          config[:username] = database_config[:username] #unless database_config[:username].nil?
          config[:password] = database_config[:password] #unless database_config[:password].nil?
          # ... = ..., maybe?
        end
      end

      #   Load a file or abort if it doesn't exists
      #   ---------------------------------------------------
      #   See this doc for load:
      #   http://www.ruby-doc.org/core-2.0/Kernel.html#method-i-load
      #
      #   Basically, load will excute all the ruby codes in "file".
      def load_or_abort(file)
        if File.exists?(file)
          load(file)
        else
          abort %{#{file} doesn't exist yet}
        end
      end

      #   Exceptions to rescue from on db operations
      #
      def rescuable_exceptions
        [ActiveRecord::StatementInvalid] + [rescue_from].flatten
      end

      #   Extra exceptions to rescue from
      #
      def rescue_from
        []
      end
    end
  end
end