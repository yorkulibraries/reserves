# frozen_string_literal: true

require 'test_helper'

module Alma
  class CourseTest < ActiveSupport::TestCase
    setup do
      Rails.logger.stubs(:error)
      Rails.logger.stubs(:info)
    end

    teardown do
      Rails.logger.unstub(:error)
      Rails.logger.unstub(:info)
    end

    should 'return reading list items when list exists' do
      Alma::ReadingList.expects(:get_reading_list_for_course).with('COURSE1').returns('LIST1')
      Alma::ReadingList.expects(:get_items_for_reading_list).with('COURSE1', 'LIST1').returns([{ 'id' => 'C1' }])

      items = Course.get_items_for_course('COURSE1')
      assert_equal ['C1'], items.map { |i| i['id'] }
    end

    should 'log and return empty array when reading list missing' do
      Alma::ReadingList.expects(:get_reading_list_for_course).with('COURSE1').returns(nil)
      Rails.logger.expects(:error).with(regexp_matches(/No reading list/))

      assert_equal [], Course.get_items_for_course('COURSE1')
    end

    should 'create new Alma course and migrate citations when missing remotely' do
      Rails.logger.stubs(:warn)
      Rails.logger.stubs(:info)

      new_course = create(:course, name: 'Migration 101', alma_instructor_id: 'INSTR-OLD')
      new_course.update!(code: '2024_GL_MIGR_F_1010__3_A')

      Alma::Course.expects(:find_by_code).with(new_course.code).returns(nil)
      Alma::Course.expects(:create).with(has_entries(
        'code' => new_course.code,
        'name' => 'Migration 101'
      )).returns({ 'id' => 'NEWCOURSE' })

      Alma::ReadingList.expects(:get_reading_list_for_course).with('OLDCOURSE').returns('OLDLIST')
      Alma::ReadingList.expects(:get_reading_list_for_course).with('NEWCOURSE').returns('NEWLIST')

      Alma::ReadingList.expects(:get_items_for_reading_list)
                      .with('OLDCOURSE', 'OLDLIST')
                      .twice
                      .returns([{ 'id' => 'CIT1' }]).then
                      .returns([])

      full_citation = {
        'id' => 'CIT1',
        'link' => 'http://example',
        'created_date' => 'yesterday',
        'last_modified_date' => 'today',
        'citation_origin' => 'remote',
        'metadata_source' => 'alma',
        'metadata' => { 'title' => 'Example Title' }
      }

      Alma::ReadingList.expects(:get_citation)
                      .with('OLDCOURSE', 'OLDLIST', 'CIT1')
                      .returns(full_citation)

      Alma::ReadingList.expects(:add_citation).with(
        course_id: 'NEWCOURSE',
        reading_list_id: 'NEWLIST',
        citation_data: full_citation.except('id', 'link', 'created_date', 'last_modified_date', 'citation_origin', 'metadata_source')
      ).returns({ 'id' => 'NEWCIT' })

      Alma::ReadingList.expects(:delete_citation)
                      .with(course_id: 'OLDCOURSE', reading_list_id: 'OLDLIST', citation_id: 'CIT1')
                      .returns(true)

      Alma::ReadingList.expects(:delete)
                      .with(course_id: 'OLDCOURSE', reading_list_id: 'OLDLIST')
                      .returns(true)

      Course.update_items_course_and_reading_list(new_course, 'OLDCOURSE')
    end

    should 'stop when reading lists cannot be found' do
      new_course = create(:course, alma_instructor_id: 'INSTR1')

      Alma::Course.expects(:find_by_code).with(new_course.code).returns({ 'id' => 'NEWCOURSE' })
      Alma::ReadingList.expects(:get_reading_list_for_course).with('OLDCOURSE').returns(nil)
      Alma::ReadingList.expects(:get_reading_list_for_course).with('NEWCOURSE').returns(nil)

      Alma::ReadingList.expects(:get_items_for_reading_list).never
      Alma::ReadingList.expects(:add_citation).never
      Alma::ReadingList.expects(:delete_citation).never
      Alma::ReadingList.expects(:delete).never

      Course.update_items_course_and_reading_list(new_course, 'OLDCOURSE')
    end
  end
end
