# frozen_string_literal: true

require 'test_helper'

class CoursesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create(:course)

    @user = create(:user, admin: true, role: User::MANAGER_ROLE)
    log_user_in(@user)
  end

  should 'list all courses' do
    create_list(:course, 10)

    get courses_path
    assert_response :success
    courses = get_instance_var(:courses)
    assert_equal 11, courses.size, '10 Courses + 1 from setup'
  end

  should 'show new course form' do
    get new_course_path
    assert_response :success
  end

  should 'create a new course' do
    assert_difference('Course.count') do
      post courses_path, params: { course: attributes_for(:course) }
      course = get_instance_var(:course)
      assert_equal 0, course.errors.size, 'Should be no errors'
      assert_redirected_to courses_path
    end
  end

  should 'show course details' do
    get course_path(@course)
    assert_response :success
  end

  should 'show get edit form' do
    get edit_course_path(@course)
    assert_response :success
  end

  should 'update an existing course' do
    old_course_code = @course.code

    patch course_path(@course), params: { course: { code: '2025_GL_ECON_W_3500__3_B' } }
    course = get_instance_var(:course)
    
    assert_equal 0, course.errors.size, "Should be no errors, #{course.errors.messages}"
    assert_response :redirect
    assert_redirected_to courses_path
    
    assert_not_equal old_course_code, course.code
    assert_equal '2025_GL_ECON_W_3500__3_B', course.code, 'Code was updated'    
  end

  # test 'autocomplete returns expected courses' do
  #   Searchkick.callbacks(:inline) do
  #     current_year = Date.today.month < 9 ? Date.today.year - 1 : Date.today.year
  #     next_year = current_year + 1
  #     allowed_code_years = [current_year.to_s, next_year.to_s]
  
  #     puts "Allowed academic years for search: #{allowed_code_years.inspect}"
  
  #     course_1 = create(:course,
  #       name: 'Macroeconomics',
  #       instructor: 'Dr. Smith',
  #       code: "#{current_year}_GL_ECON_F_1010_3_A",
  #       code_year: current_year.to_s,
  #       year: current_year,
  #       faculty: 'GL',
  #       subject: 'ECON',
  #       term: 'F',
  #       course_id: 1010,
  #       credits: 3,
  #       section: 'A'
  #     )
  
  #     course_2 = create(:course,
  #       name: 'Microeconomics',
  #       instructor: 'Dr. Lee',
  #       code: "#{next_year}_GL_ECON_F_1020_3_B",
  #       code_year: next_year.to_s,
  #       year: next_year,
  #       faculty: 'GL',
  #       subject: 'ECON',
  #       term: 'F',
  #       course_id: 1020,
  #       credits: 3,
  #       section: 'B'
  #     )
  
  #     puts "Created Course 1: #{course_1.code}, code_year: #{course_1.code_year}, valid?: #{course_1.valid?}, errors: #{course_1.errors.full_messages}"
  #     puts "Created Course 2: #{course_2.code}, code_year: #{course_2.code_year}, valid?: #{course_2.valid?}, errors: #{course_2.errors.full_messages}"
  
  #     Course.reindex
  #     Course.search_index.refresh
  
  #     puts "\nAll indexed course codes:"
  #     Course.search('*', load: true).each do |c|
  #       puts "- #{c.code} (code_year: #{c.code_year})"
  #     end
  
  #     get autocomplete_courses_path, params: { term: 'ECON' }
  
  #     assert_response :success
  #     result = JSON.parse(response.body)
  
  #     puts "\nSearch result for term 'ECON':"
  #     result.each { |r| puts "- #{r['label']}" }
  
  #     assert_equal 2, result.size, "Expected 2 matching courses, got: #{result.inspect}"
  
  #     labels = result.map { |r| r['label'] }
  
  #     assert_includes labels, "#{course_1.code} / #{course_1.name} / #{course_1.instructor}"
  #     assert_includes labels, "#{course_2.code} / #{course_2.name} / #{course_2.instructor}"
  #   end
  # end
  
     

  should 'should return empty array if no matching courses' do
    Course.reindex
    get autocomplete_courses_path, params: { term: 'UNMATCHABLE_TERM' }

    assert_response :success
    result = JSON.parse(response.body)
    assert_equal [], result
  end
  
  should 'destroy course' do
    assert_difference('Course.count', -1) do
      delete course_path(@course)
    end

    assert_redirected_to courses_path
  end
end
