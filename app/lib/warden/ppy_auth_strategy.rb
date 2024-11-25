require 'devise/strategies/authenticatable'
require 'digest'

class Warden::PpyAuthStrategy < Devise::Strategies::Authenticatable
  CYIN = 'HTTP_PYORK_CYIN'
  USER = 'HTTP_PYORK_USER'
  FIRSTNAME = 'HTTP_PYORK_FIRSTNAME'
  SURNAME = 'HTTP_PYORK_SURNAME'
  EMAIL = 'HTTP_PYORK_EMAIL'
  TYPE = 'HTTP_PYORK_TYPE'

  LOGIN = ['/login']
  LOGOUT_URL = 'https://passportyork.yorku.ca/ppylogin/ppylogout'

  def authenticate!
    if valid?
      resource = User.find_by('uid = ?', request.headers[USER])
      if !resource.present?
        @user = User.new
        @user.password = Digest::SHA256.hexdigest(rand().to_s)
        @user.admin = false
        @user.active = true
        @user.user_type = User::UNKNOWN if @user.user_type.nil?
        @user.role = User::INSTRUCTOR_ROLE
        @user.uid = request.headers[USER]
        @user.username = request.headers[USER]
        @user.name = "#{request.headers[FIRSTNAME]} #{request.headers[SURNAME]}"
        @user.email = request.headers[EMAIL]
        @user.univ_id = request.headers[CYIN]
        @user.audit_comment = 'PpyAuthStrategy created new user from authenticated PYORK headers'
        @user.save(validate: false)
        UserMailer.welcome(@user).deliver_later if @user.email.present?
        resource = @user
      end

      if resource.univ_id.nil?
        resource.univ_id = request.headers[CYIN]
      end

      if resource.update_external_alma(request.headers[CYIN])
        resource.audit_comment = 'Updated user information from ALMA'
      end

      resource.save(validate: false) if resource.changed?

      success!(resource)
    else
      Rails.logger.debug "not valid"
      fail!('Not authenticated')
    end
  end

  def valid?
    return LOGIN.include?(request.path) && !request.headers[USER].nil?
  end
end