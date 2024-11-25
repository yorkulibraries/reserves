# frozen_string_literal: true

class ApplicationController < ActionController::Base
  layout :layout_by_resource

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  check_authorization :unless => :do_not_check_authorization?

  before_action :login_required
  before_action :user_information_validity_check, if: :logged_in?

  def _current_user
    @current_user ||= User.find_by_id(session[:user_id]) if session[:user_id]
    @current_user ||= current_user
  end

  def current_ability
    @current_ability ||= Ability.new(_current_user, params)
  end

  def logged_in?
    user_signed_in?
  end

  def login_required
    unless logged_in? || controller_name == 'sessions'
      session[:redirect_to] = request.fullpath unless request.fullpath == login_path
      redirect_to login_url, alert: 'You must login before accessing this page.'
    end
  end

  def user_information_validity_check
    if !_current_user.admin && (_current_user.name.blank? || _current_user.email.blank?) && controller_name == 'users'
      redirect_to edit_user_path(_current_user),
                  notice: "Please update your user information before continuing."
    end
  end

  rescue_from CanCan::AccessDenied do |exception|
    render 'access_denied', layout: 'simple', :status => :unauthorized
  end

  private
  def do_not_check_authorization?
    respond_to?(:devise_controller?)
  end

  def layout_by_resource
    if devise_controller?
      "simple"
    else
      "application"
    end
  end
end
