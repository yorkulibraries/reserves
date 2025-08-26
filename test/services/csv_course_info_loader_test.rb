require 'test_helper'

class CsvCourseInfoLoaderTest < ActiveSupport::TestCase
  setup do
    @file_path = Rails.root.join('test', 'fixtures', 'courses.csv').to_s
  end

  test 'loads all CSV rows as new CourseInfo records' do    
    # Verify the number of records
    assert_difference('CourseInfo.count', 2, 'Expected 2 CourseInfo records to be created') do
      result = CsvCourseInfoLoader.new(@file_path).call
    end

    # Verify the first record
    course1 = CourseInfo.find_by(crs_id: 'HH/COOP 2999   3.00')
    assert_not_nil course1, 'Expected first course to be created'
    assert_equal 'Faculty of Health', course1.faculty
    assert_equal '2025', course1.academic_year, 'Expected academic_year to be loaded correctly'
    assert_equal 'Preparing for Co-op Work in Health and Health-related Environments', course1.course_title
    assert_equal 'Preparing for Co-op Work in Health and Health-related Environments', course1.course_title1
    assert_equal 3, course1.credit
    assert_nil course1.instructor_name, 'Expected instructor_name to be nil for empty string'

    # Verify the second record
    course2 = CourseInfo.find_by(crs_id: 'HH/GH   4000   3.00', section: 'A')
    assert_not_nil course2, 'Expected second course to be created'
    assert_equal '2024', course2.academic_year, 'Expected academic_year to be loaded correctly'
    assert_equal 'Independent Study', course2.course_title
    assert_equal 'Independent Study', course2.course_title1
    assert_equal 'John Smith', course2.instructor_name
  end

  test "handles invalid file path" do
    file_path = Rails.root.join('test', 'fixtures', 'nonexistent.csv').to_s
    result = CsvCourseInfoLoader.new(file_path).call
    assert_not result.success, "Expected import to fail"
    assert_match /File not found/, result.errors.first
  end

  test "handles invalid CSV data" do
    invalid_csv = Rails.root.join('test', 'fixtures', 'invalid_courses.csv').to_s
    result = CsvCourseInfoLoader.new(invalid_csv).call
    assert_not result.success, "Expected import to fail"
    assert_not_empty result.errors
    assert_match /Failed to save course/, result.errors.first
  end
end