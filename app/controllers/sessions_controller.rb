# frozen_string_literal: true

class SessionsController < ApplicationController
  # manually handling session user switching
  before_action :authenticate_user!, except: [:destroy, :login_as, :back_to_my_login]
  skip_authorization_check except: %i[login_as back_to_my_login]

  def new
    user = current_user # use Devise "current_user" helper to get logged in user

    session[:user_id] = user.id
    if user.active?
      if user.admin?
        redirect_to root_url, notice: 'Logged in!'
        return
      end

      if user.name.nil? || user.phone.nil? || user.office.nil?
        redirect_to edit_user_url(user), notice: 'Welcome! Please tell us about yourself.'
      else
        redirect_to requests_user_url(user), notice: 'Welcome back!' unless user.admin?
      end
    else
      destroy_session
      flash.alert = 'User not active.'
      render layout: 'simple', :status => :unauthorized
    end
  end

  def destroy_session
    sign_out :user # use Devise "sign_out" helper to sign out
    session[:user_id] = nil
    request.env['warden'] = nil if request.env['warden'].present?
  end

  def destroy
    destroy_session
    redirect_to Warden::PpyAuthStrategy::PPY_LOGOUT_URL, allow_other_host: true
  end

  def login_as
    authorize! :login_as, :requestor

    requestor = User.find_by_id(params[:who])

    if requestor && !requestor.admin?
      session[:back_to_id] = current_user&.id
      name = current_user.name

      session[:user_id] = requestor.id
      session[:back_to_url] = request.referer
  
      requestor.audit_comment = "#{name} logged into #{requestor.name}'s account"
      requestor.save(validate: false)
  
      sign_out(:user) # Log out current Devise user before impersonating
  
      redirect_to requests_user_url(requestor)
    else
      redirect_to root_url, notice: 'Requestor not found'
    end
  end
  

  def back_to_my_login
    authorize! :back_to_login, :requestor

    unless session[:back_to_id].nil?
      requestor = current_user

      u = User.find_by_id(session[:back_to_id])
  
      ## updated audit trail
      requestor.audit_comment = "#{u.name} logged out from #{requestor.name}'s account"
      requestor.touch # This updates updated_at and triggers auditing

      session[:user_id] = u.id
      session[:back_to_id] = nil

      sign_in(:user, u) # Re-establish Devise session for the original user
  
      if session[:back_to_url].nil?
        redirect_to root_url
      else
        redirect_to session[:back_to_url]
      end
    end
  end
  
end
