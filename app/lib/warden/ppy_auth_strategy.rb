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
  PPY_LOGOUT_URL = 'https://passportyork.yorku.ca/ppylogin/ppylogout'

  def authenticate!
    if valid?
      resource = User.find_by('username = ?', request.headers[USER])
      if !resource.present?
        @user = User.new
        @user.password = Digest::SHA256.hexdigest(rand().to_s)
        @user.admin = false
        @user.active = true
        @user.user_type = request.headers[TYPE]
        @user.role = User::INSTRUCTOR_ROLE
        @user.uid = request.headers[USER]
        @user.username = request.headers[USER]
        @user.name = "#{request.headers[FIRSTNAME]} #{request.headers[SURNAME]}"
        @user.email = request.headers[EMAIL]
        @user.univ_id = request.headers[CYIN]
        @user.audit_comment = 'PpyAuthStrategy created new user from authenticated PYORK headers'
        
        if !@user.valid?
          fail!('Not authenticated. User validation failed.')
          return false
        end

        @user.save
        UserMailer.welcome(@user).deliver_later if @user.email.present?
        resource = @user
      end

      resource.user_type = request.headers[TYPE]
      resource.uid = request.headers[USER]
      resource.username = request.headers[USER]
      resource.email = request.headers[EMAIL]
      resource.univ_id = request.headers[CYIN]

      if resource.changed?
        resource.audit_comment = 'Updated user information from PYORK headers'
        resource.save
      end

      if resource.role == User::INSTRUCTOR_ROLE
        if resource.update_external_alma(request.headers[CYIN])
          if resource.changed?
            resource.audit_comment = 'Updated user information from ALMA'
            resource.save
          end
        end
      end

      success!(resource)
    else
      fail!('Not authenticated. Warden::PpyAuthStrategy not valid.')
    end
  end

  def valid?
    return LOGIN.include?(request.path) && !request.headers[USER].nil?
  end
end