require 'spec_helper'

describe Apartment::Reloader do

  context "using mysql" do

    before do
      Apartment.excluded_models = ["Company"]
      Company.reset_table_name  # ensure we're clean
    end

    subject{ Apartment::Reloader.new(double("Rack::Application", :call => nil)) }

    it "should initialize apartment when called" do
      Company.table_name.should == "companies"
      subject.call(double('env'))
      Company.table_name.should == "companies"
    end
  end
end
