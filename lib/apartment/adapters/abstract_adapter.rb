require 'active_record'

module Apartment
  module Adapters
    class AbstractAdapter

      #  @constructor
      #  @param {Hash} config Database config
      #  ------------------------------------------------------
      #  Example of what @config might be: 
      #          {:adapter=>"mysql2", 
      #           :encoding=>"utf8", 
      #           :reconnect=>false, 
      #           :database=>"nemo", 
      #           :pool=>5, 
      #           :username=>"root", 
      #           :password=>nil, 
      #           :host=>"127.0.0.1", 
      #           :port=>3306}
      def initialize(config)
        @config = config
      end

      #   Create a new database, import schema, seed if appropriate
      #   @param {Hash} database_config, 
      #         complete info of a database, :database, :host, ...
      #   --------------------------------------------------------
      def create(database_config, import_schema=true)
        create_database(database_config)

        # Switch to created new db and do stuff, like seed, then switch back to cur db.
        process(database_config) do
          import_database_schema if import_schema

          # Seed data if appropriate
          seed_data if Apartment.seed_after_create

          yield if block_given?
        end
      end

      #   Get the current database config
      #   ---------------------------------------
      def current_database
        Apartment.connection_config
      end

      # return {string}, name of the current database
      def current_database_name
        Apartment.connection_config[:target_database]
      end

      #   Note alias_method here doesn't work with inheritance apparently ??
      #
      def current
        current_database
      end

      #   Drop the database
      def drop!(database_config)
        # Apartment.connection.drop_database   note that drop_database will not throw an exception, so manually execute
        
        process(database_config) do
          Apartment.connection.execute("DROP DATABASE #{database_config[:target_database]}" )
        end

        Apartment.connection_config[:target_database] = nil if self.current_database_name == database_config[:target_database]

      rescue *rescuable_exceptions
        raise DatabaseNotFound, "The database #{database_config[:target_database]} cannot be found"
      end

      #   Connect to db, do your biz, switch back to previous db
      #   --------------------------------------------------------
      #   @param {Hash} database_config, 
      #         complete info of a database, :database, :host, ...
      #   {Boolean} choose if use USE statement while switching to the database_config
      def process(database_config = nil, use_use=true)
        current_db = current_database.dup

        switch(database_config, use_use)

        yield if block_given?

      ensure
        # Always use USE while switching back.
        switch(current_db) rescue reset
      end

      #   Establish a new connection for each specific excluded model
      def process_excluded_models
        # All other models will shared a connection (at Apartment.connection_class) and we can modify at will
        Apartment.excluded_models.each do |excluded_model|
          excluded_model.constantize.establish_connection @config
        end
      end

      ## Current logic just connect to the default config, which should be defined in the database.yml file.
      #   Reset the database connection to the default
      #   --------------------------------------
      def reset
        Apartment.establish_connection @config
        Apartment.connection_config[:target_database] = Apartment.connection_config[:database]
      end

      #   Switch to new connection (or schema if appropriate)
      #
      #   @param {Hash} database_config, :database, :host
      #   {Boolean} choose if use USE statement while switching to the database_config
      #   ------------------------------------------------
      #   Doc on .tap method.
      #   http://apidock.com/rails/Object/tap
      def switch(database_config=nil, use_use=true)
        # Just connect to default db and return
        return reset if database_config.nil?

        connect_to_new(database_config, use_use).tap do
          ActiveRecord::Base.connection.clear_query_cache
        end

      end

      #   Load the rails seed file into the db
      #   ------------------------------------------------
      #   Explanation on silence_stream:
      #   http://apidock.com/rails/Kernel/silence_stream
      def seed_data
        silence_stream(STDOUT){ load_or_abort("#{Rails.root}/db/seeds.rb") } # Don't log the output of seeding the db
      end
      alias_method :seed, :seed_data

    protected

      #   Create the database
      #
      #   @param {Hash} database_config, 
      #         complete info of a database, :database, :host, ...
      #   --------------------------------------
      def create_database(database_config)
        process(database_config, false) do
          Apartment.connection.create_database database_config[:target_database]
        end

        # Change the configuration back.
      rescue *rescuable_exceptions
        raise DatabaseExists, "The database #{database_config[:target_database]} already exists."
      end

      #   Connect to new database
      #   @param 
      #     {Hash} database_config, complete info of a database, :database, :host, ...
      #     {Boolean} use_use, if use USE statement. In creation process, we do not want to use use since there is not db to use.
      #   --------------------------------------
      #   THIS METHOD IS OVERWRITTEN IN lib/adapters/mysql2_adapter.rb
      #   To do the "connect to db server, use correct db" trick.
      def connect_to_new(database_config, use_use)
        Apartment.establish_connection database_config
        Apartment.connection.active?   # call active? to manually check if this connection is valid

      rescue *rescuable_exceptions
        raise DatabaseNotFound, "The database #{database_config[:target_database]} cannot be found."
      end


      #   Import the database schema
      def import_database_schema
        ActiveRecord::Schema.verbose = false    # do not log schema load output.

        load_or_abort(Apartment.database_schema_file) if Apartment.database_schema_file
      end

      #   Load a file or abort if it doesn't exists
      #   ---------------------------------------------------
      #   See this doc for load:
      #   http://www.ruby-doc.org/core-2.0/Kernel.html#method-i-load
      #
      #   Basically, load will execute all the ruby codes in "file".
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