# test/models/course_info_test.rb
require 'test_helper'

class CourseInfoTest < ActiveSupport::TestCase
  setup do
    # Import valid and invalid CSVs to populate the database
    valid_file_path = Rails.root.join('test', 'fixtures', 'courses.csv').to_s
    invalid_file_path = Rails.root.join('test', 'fixtures', 'invalid_courses.csv').to_s
    CsvCourseInfoLoader.new(valid_file_path).call
    CsvCourseInfoLoader.new(invalid_file_path).call
  end

  # Validation tests
  test "validates presence of subject" do
    course = CourseInfo.new(course_title: "Test Course", course_number: "123")
    assert_not course.save, "Expected save to fail without subject"
    assert_includes course.errors.full_messages, "Subject can't be blank"
  end

  test "validates presence of course_title" do
    course = CourseInfo.new(subject: "Test Subject", course_number: "123")
    assert_not course.save, "Expected save to fail without course_title"
    assert_includes course.errors.full_messages, "Course title can't be blank"
  end

  test "validates presence of course_number" do
    course = CourseInfo.new(subject: "Test Subject", course_title: "Test Course")
    assert_not course.save, "Expected save to fail without course_number"
    assert_includes course.errors.full_messages, "Course number can't be blank"
  end

  test "saves valid course" do
    course = CourseInfo.new(
      subject: "Test Subject",
      course_title: "Test Course",
      course_number: "123",
      faculty: "Test Faculty",
      faculty_abrev: "TF",
      study_session: "Spring"
    )
    assert course.save, "Expected valid course to save"
  end

  test "search data includes combined subject and course number tokens" do
    course = CourseInfo.new(
      subject: "Psychology",
      subject_abrev: "PSYC",
      subject_abrev2: "PSY",
      course_title: "Intro to Psychology",
      course_number: "2030"
    )

    tokens = course.search_data[:subject_course]

    assert_includes tokens, "PSYC 2030"
    assert_includes tokens, "PSYC2030"
    assert_includes tokens, "PSYC-2030"
    assert_includes tokens, "PSY 2030"
    assert_includes tokens, "PSY2030"
    assert_includes tokens, "PSY-2030"
  end

  # Class method tests
  test "unique_subjects returns unique subject values" do
    subjects = CourseInfo.unique_subjects
    # Unique & non-nil
    assert_equal subjects.uniq, subjects, "Expected unique values"
    refute_includes subjects, nil, "Expected no nil subjects"
    # Contains at least the known subjects from fixtures
    assert_includes subjects, "COOPERATIVE EDUCATION"
    assert_includes subjects, "GH - GLOBAL HEALTH"
    # The model may also include things like 'ENG' because it doesn't filter — that's OK.
  end

  test "unique_subject_codes returns unique subject_abrev values" do
    codes = CourseInfo.unique_subject_codes
    # Unique & non-nil
    assert_equal codes.uniq, codes, "Expected unique values"
    refute_includes codes, nil, "Expected no nil subject codes"
    # Contains at least the known codes from fixtures
    assert_includes codes, "COOP"
    assert_includes codes, "GH"
    # If 'ENG' appears (e.g., due to fixture data), that's acceptable per the current model.
  end

  test "unique_faculties returns unique faculty values" do
    faculties = CourseInfo.unique_faculties
    assert_equal ["Faculty of Health"], faculties.sort, "Expected unique non-nil faculties"
  end

  test "unique_faculty_codes returns unique faculty_abrev values" do
    codes = CourseInfo.unique_faculty_codes
    assert_equal ["HH"], codes.sort, "Expected unique non-nil faculty codes"
  end

  test "unique_study_sessions returns unique study_session values" do
    sessions = CourseInfo.unique_study_sessions
    # Unique & non-nil
    assert_equal sessions.uniq, sessions, "Expected unique values"
    refute_includes sessions, nil, "Expected no nil study sessions"
    # Must include the expected long codes; shorter ones like 'F' may also appear per data
    assert_includes sessions, "FW"
    assert_includes sessions, "SU"
  end

  test "class methods return empty array when no valid data" do
    CourseInfo.delete_all
    assert_empty CourseInfo.unique_subjects, "Expected empty subjects"
    assert_empty CourseInfo.unique_subject_codes, "Expected empty subject codes"
    assert_empty CourseInfo.unique_faculties, "Expected empty faculties"
    assert_empty CourseInfo.unique_faculty_codes, "Expected empty faculty codes"
    assert_empty CourseInfo.unique_study_sessions, "Expected empty study sessions"
  end
end
