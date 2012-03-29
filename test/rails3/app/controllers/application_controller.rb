class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :set_abongo_identity

  def set_abongo_identity
    if session[:abongo_identity]
      Abongo.identity = session[:abongo_identity]
    else
      Abongo.identity = session[:abongo_identity] = rand(10 ** 10).to_i
    end
  end

end
