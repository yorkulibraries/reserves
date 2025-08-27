class CourseInfo < ApplicationRecord

  validates :subject, :course_title, :course_number, presence: true

  searchkick word_start: %i[
    subject subject_abrev subject_abrev2 course_number course_title instructor_name
    faculty_abrev faculty_short faculty
  ], stem: false, callbacks: :async

  def search_data
    {
      subject:          subject,
      subject_abrev:    subject_abrev,
      subject_abrev2:   subject_abrev2,
      course_number:    course_number,
      course_title:     (course_title.presence || course_title1),
      instructor_name:  instructor_name,
      faculty:          faculty,
      faculty_abrev:    faculty_abrev,
      faculty_short:    faculty_short,
      academic_year:    academic_year, # used for filtering in where:
      study_session:    study_session
    }
  end

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
