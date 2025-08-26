class CourseInfo < ApplicationRecord
  validates :subject, presence: true
  validates :course_title, presence: true
  validates :course_number, presence: true

  def self.unique_subjects
    where.not(subject: nil).distinct.pluck(:subject)
  end

  def self.unique_subject_codes
    where.not(subject: nil).distinct.pluck(:subject_abrev)
  end

  def self.unique_faculties
    where.not(subject: nil).distinct.pluck(:faculty)
  end

  def self.unique_faculty_codes
    where.not(subject: nil).distinct.pluck(:faculty_abrev)
  end

  def self.unique_study_sessions
    where.not(subject: nil).distinct.pluck(:study_session)
  end
end
