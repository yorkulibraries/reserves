# frozen_string_literal: true

class User < ApplicationRecord
  searchkick
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :trackable, :lockable

  ## CONSTANTS
  FACULTY = 'FACULTY'
  GRADUATE = 'GRADUATE'
  UNDERGRAD = 'UNDERGRAD'
  STAFF = 'STAFF'
  UNKNOWN = 'unknown'
  TYPES = [FACULTY, GRADUATE, UNDERGRAD, STAFF].freeze

  MANAGER_ROLE = 'manager'
  SUPERVISOR_ROLE = 'supervisor'
  STAFF_ROLE = 'staff'
  INSTRUCTOR_ROLE = 'instructor'
  STUDENT_ROLE = 'student'
  STAFF_ROLES = [MANAGER_ROLE, SUPERVISOR_ROLE, STAFF_ROLE].freeze
  USER_ROLES = [INSTRUCTOR_ROLE, STUDENT_ROLE].freeze

  ## RELATIONSHIPS
  has_many :requests, foreign_key: 'requester_id', class_name: 'Request'
  belongs_to :created_by, foreign_key: 'created_by_id', class_name: 'User'
  belongs_to :location

  ## VALIDATIONS
  validates_presence_of :name, :email, :uid, :user_type, :role, :username
  validates_presence_of :department, :phone, :office, unless: proc { |u| u.admin? }
  validates_presence_of :location, if: proc { |u| u.admin? }
  validates :email, presence: true, uniqueness: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }

  validates_uniqueness_of :uid
  validates_uniqueness_of :username

  ## SCOPES
  scope :admin, -> { where(admin: true) }
  scope :users, -> { where(admin: false) }

  scope :inactive, -> { where(active: false) }
  scope :active, -> { where(active: true) }

  ## AUDITS
  audited associated_with: :location
  has_associated_audits

  def update_external_alma(user_id)
    return false if user_id.nil? || Setting.alma_apikey.nil? || Setting.alma_apikey.strip.length == 0

    Alma.configure do |config|
      config.apikey = Setting.alma_apikey
      config.region = Setting.alma_region
    end

    logger.info "Searching for user in ALMA with id: #{user_id}"
    user = Alma::User.find(user_id)

    begin
      self.name = "#{user.first_name} #{user.last_name}"
      self.email = user.preferred_email
      self.phone = begin
        user['contact_info']['phone'].first['phone_number']
      rescue StandardError
        self.phone
      end

      office_address = nil
      user['contact_info']['address'].each do |a|
        next unless a['preferred'].to_s == 'true'

        office_address = begin
          a['line1']
        rescue StandardError
          nil
        end
      end

      self.office = if office_address.nil?
                      begin
                        user['contact_info']['address'].first['line1'].strip
                      rescue StandardError
                        self.office
                      end
                    else
                      office_address
                    end

      self.library_uid = begin
        user['primary_id']
      rescue StandardError
        self.library_uid
      end

      self.user_type = begin
        user.user_group['value']
      rescue StandardError
        self.user_type
      end

      return true
    rescue Exception => e
      logger.debug 'Failed to parse User Profile Response from source ALMA'
      return false
    end
  end

  def inactive?
    active == false
  end
end
