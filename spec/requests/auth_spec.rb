require 'spec_helper'

describe "resources which require authentication" do
  let!(:user) { User.create! :username => 'some_user', :password => 'secret', :first_name => "Jeau", :last_name => "Bleau", :email => "jb@emc.com" }

  context "after the user has logged in" do
    before do
      post "/sessions", :username => "some_user", :password => "secret"
    end

    it "shows the resource" do
      get "/users"
      response.code.should == "200"
    end

    context "then logged out" do
      before do
        delete "/sessions"
      end

      it "refuses to show the resource" do
        get "/users"
        response.code.should == "401"
      end
    end
  end

  context "when the user has never logged in" do
    it "refuses to show the resource" do
      get "/users"
      response.code.should == "401"
    end
  end
end