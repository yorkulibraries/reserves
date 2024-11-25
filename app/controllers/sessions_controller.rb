# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :authenticate_user!, except: :destroy
  skip_authorization_check except: %i[login_as back_to_my_login]

  def new
    current_user = request.env['warden'].authenticate!
    session[:user_id] = current_user.id if current_user.present?
    if current_user
      if current_user.active?
        update_successful = current_user.update_external(request.headers['HTTP_PYORK_CYIN'])
        if update_successful
          current_user.audit_comment = 'Updated user information from ALMA'
          current_user.save(validate: false)
        end

        if session[:redirect_to].nil?
          redirect_to root_url, notice: 'Logged in!' if current_user.admin?
          if current_user.name.nil? || current_user.phone.nil? || current_user.office.nil?
            redirect_to edit_user_url(current_user), notice: 'Welcome! Please tell us about yourself.'
          else
            redirect_to requests_user_url(current_user), notice: 'Welcome back!' unless current_user.admin?
          end
        else
          url = session[:redirect_to]
          session[:redirect_to] = nil
          redirect_to url, notice: 'Logged in!'
        end
      else
        redirect_to inactive_user_url, alert: 'Your Account Has Been Disabled'
      end
    end
  end

  def destroy
    Rails.logger.debug "#{session[:user_id]} , user_id #{:user_id}"
    Rails.logger.debug "Logging out #{:user}"

    sign_out :user
    
    session[:user_id] = nil

    Rails.logger.debug "request.env['warden'] = #{request.env['warden']}"
    request.env['warden'] = nil if request.env['warden'].present?

    redirect_to Warden::PpyAuthStrategy::LOGOUT_URL, allow_other_host: true
  end

  def invalid_login
    render layout: 'simple'
  end

  def unauthorized
    render layout: 'simple'
  end

  def inactive_account_url
    render layout: simple
  end

  def login_as
    authorize! :login_as, :requestor

    who = params[:who]
    requestor = User.find_by_id(who)

    if requestor && !requestor.admin?
      session[:back_to_id] = current_user.id
      name = current_user.name

      session[:user_id] = requestor.id
      session[:back_to_url] = request.referer

      ## updated audit trail
      requestor.audit_comment = "#{name} logged into #{requestor.name}'' account"
      requestor.save(validate: false)

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
      requestor.save(validate: false)

      session[:user_id] = u.id
      session[:back_to_id] = nil

      if session[:back_to_url].nil?
        redirect_to root_url
      else
        redirect_to session[:back_to_url]
      end
    end
  end
end
