# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  before_filter :set_abongo_identity

  def set_abongo_identity
    if session[:abongo_identity]
      Abongo.identity = session[:abongo_identity]
    else
      Abongo.identity = session[:abongo_identity] = rand(10 ** 10).to_i
    end
  end

  
end
