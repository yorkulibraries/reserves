# frozen_string_literal: true

require 'test_helper'

module Alma
  class SyncRequestTest < ActiveSupport::TestCase
    setup do
      @user = create(:user, email: 'sync@example.com')
      Rails.logger.stubs(:info)
      Rails.logger.stubs(:warn)
      Rails.logger.stubs(:error)
    end

    teardown do
      Rails.logger.unstub(:info)
      Rails.logger.unstub(:warn)
      Rails.logger.unstub(:error)
      Date.unstub(:today) if Date.respond_to?(:unstub)
    end

    should 'log error and return when course is missing' do
      request = create(:request)
      request.stubs(:course_id).returns(999)

      ::Course.expects(:find_by).with(id: 999).returns(nil)
      Rails.logger.expects(:error).with(regexp_matches(/Request##{request.id} has no Course/))

      Alma::AlmaSync.sync_request(request, @user)
    end

    should 'create Alma course and reading list when missing' do
      course = create(:course, alma_instructor_id: nil)
      request = create(:request, course: course)

      ::Course.expects(:find_by).with(id: course.id).returns(course)

      Alma::AlmaSync.expects(:create_or_find_instructor).with(course).returns('INSTR1')
      course.expects(:update_column).with(:alma_instructor_id, 'INSTR1').returns(true)

      Alma::AlmaSync.expects(:alma_course_code_for).with(course).returns('ECON1010')
      Alma::AlmaSync.expects(:reading_list_name_for).with(course).returns('ECON1010_JaneDoe')

      Date.stubs(:today).returns(Date.new(2024, 1, 2))

      Alma::Course.expects(:find_by_code).with('ECON1010').returns(nil)
      Alma::Course.expects(:create).with(has_entries(
        'code' => 'ECON1010',
        'name' => course.name,
        'status' => 'ACTIVE'
      )).returns({ 'id' => 'COURSEID' })

      request.expects(:update_column).with(:alma_course_id, 'COURSEID').returns(true)

      Alma::ReadingList.expects(:find_by_name).with('COURSEID', 'ECON1010_JaneDoe').returns(nil)
      Alma::ReadingList.expects(:create).with(course_id: 'COURSEID', name: 'ECON1010_JaneDoe', description: 'Auto-generated from Reserves app').returns({ 'id' => 'LISTID' })

      request.expects(:update_column).with(:alma_reading_list_id, 'LISTID').returns(true)

      Alma::AlmaSync.sync_request(request, @user)
    end

    should 'reuse existing Alma course and reading list when present' do
      course = create(:course, alma_instructor_id: 'INSTR1')
      request = create(:request, course: course)

      ::Course.expects(:find_by).with(id: course.id).returns(course)

      Alma::AlmaSync.expects(:create_or_find_instructor).never
      course.expects(:update_column).never

      Alma::AlmaSync.expects(:alma_course_code_for).with(course).returns('ECON1010')
      Alma::AlmaSync.expects(:reading_list_name_for).with(course).returns('ECON1010_JaneDoe')

      Alma::Course.expects(:find_by_code).with('ECON1010').returns({ 'id' => 'COURSEID' })
      Alma::Course.expects(:create).never

      request.expects(:update_column).with(:alma_course_id, 'COURSEID').returns(true)

      Alma::ReadingList.expects(:find_by_name).with('COURSEID', 'ECON1010_JaneDoe').returns({ 'id' => 'LISTID' })
      Alma::ReadingList.expects(:create).never

      request.expects(:update_column).with(:alma_reading_list_id, 'LISTID').returns(true)

      Alma::AlmaSync.sync_request(request, @user)
    end
  end

  class AlmaSyncTest < ActiveSupport::TestCase
    setup do
      @request = create(
        :request,
        alma_course_id: 'COURSE123',
        alma_reading_list_id: 'LIST123'
      )

      @item = create(:item, request: @request, alma_citation_id: nil)
      @user = create(:user)
    end

    should 'create citation in Alma and persist citation id' do
      Alma::ReadingList.expects(:add_citation).with(
        course_id: 'COURSE123',
        reading_list_id: 'LIST123',
        citation_data: kind_of(Hash)
      ).returns({ 'id' => 'CIT-123' })

      Alma::ReadingList.expects(:delete_citation).never

      Alma::AlmaSync.sync_item(@item, @user)

      assert_equal 'CIT-123', @item.reload.alma_citation_id
    end

    should 'replace existing citation when alma_citation_id present' do
      @item.update_column(:alma_citation_id, 'CIT-OLD')

      Alma::ReadingList.expects(:delete_citation).with(
        course_id: 'COURSE123',
        reading_list_id: 'LIST123',
        citation_id: 'CIT-OLD'
      ).returns(true)

      Alma::ReadingList.expects(:add_citation).with(
        course_id: 'COURSE123',
        reading_list_id: 'LIST123',
        citation_data: kind_of(Hash)
      ).returns({ 'id' => 'CIT-NEW' })

      Alma::AlmaSync.sync_item(@item, @user)

      assert_equal 'CIT-NEW', @item.reload.alma_citation_id
    end

    should 'skip Alma citation when request is missing identifiers' do
      @request.update!(alma_course_id: nil, alma_reading_list_id: nil)
      Alma::ReadingList.expects(:add_citation).never

      Alma::AlmaSync.sync_item(@item, @user)

      assert_nil @item.reload.alma_citation_id
    end
  end

  class ReadingListSyncTest < ActiveSupport::TestCase
    setup do
      @request = create(:request, alma_course_id: 'COURSE1', alma_reading_list_id: 'LIST1')
      @actor   = create(:user)
      Rails.logger.stubs(:info)
      Rails.logger.stubs(:warn)
      Rails.logger.stubs(:error)
    end

    teardown do
      Rails.logger.unstub(:info)
      Rails.logger.unstub(:warn)
      Rails.logger.unstub(:error)
    end

    should 'skip sync when request lacks Alma identifiers' do
      @request.update!(alma_course_id: nil, alma_reading_list_id: nil)
      Alma::ReadingList.expects(:get_items_for_reading_list).never

      result = ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)

      assert_equal :skipped, result[:status]
      assert_equal 0, result[:added_local]
      assert_equal 0, result[:added_remote]
    end

    should 'create local items for Alma-only citations' do
      citation = {
        'id' => 'CIT-10',
        'metadata' => {
          'title' => 'Remote Book',
          'author' => 'Remote Author',
          'publisher' => 'Remote Press',
          'publication_date' => '2023',
          'isbn' => '9781234567890',
          'call_number' => 'QA123 .R45'
        },
        'type' => { 'value' => 'BK' }
      }

      Alma::ReadingList.expects(:get_items_for_reading_list)
                        .with('COURSE1', 'LIST1')
                        .returns([citation])

      assert_difference('Item.count', 1) do
        result = ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)
        assert_equal :ok, result[:status]
        assert_equal 1, result[:added_local]
      end

      new_item = @request.items.order(:created_at).last
      assert_equal 'Remote Book', new_item.title
      assert_equal 'Remote Author', new_item.author
      assert_equal 'Remote Press', new_item.publisher
      assert_equal '9781234567890', new_item.isbn
      assert_equal 'CIT-10', new_item.alma_citation_id
    end

    should 'not create remote citation when local item lacks Alma id (async job handles it)' do
      item = create(:item, request: @request, alma_citation_id: nil)

      Alma::ReadingList.expects(:get_items_for_reading_list)
                        .with('COURSE1', 'LIST1')
                        .returns([])

      Alma::AlmaSync.expects(:sync_item).never

      result = ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)

      assert_equal :ok, result[:status]
      assert_equal 0, result[:added_remote]
      assert_equal 0, result[:removed_local]
    end

    should 'remove local items when Alma citation missing' do
      item = create(:item, request: @request, alma_citation_id: 'CIT-MISSING')

      Alma::ReadingList.expects(:get_items_for_reading_list)
                        .with('COURSE1', 'LIST1')
                        .returns([])

      Alma::AlmaSync.expects(:sync_item).never

      assert_no_difference('Item.count') do
        result = ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)

        assert_equal :ok, result[:status]
        assert_equal 1, result[:removed_local]
        assert_equal 0, result[:added_remote]
      end

      assert_equal Item::STATUS_DELETED, item.reload.status
    end

    should 'collect failed local creations when new item invalid' do
      citation = {
        'id' => 'CIT-99',
        'metadata' => {
          'title' => 'Invalid Book',
          'author' => '',
          'publisher' => '',
          'publication_date' => '2023',
          'isbn' => '9789876543210'
        },
        'type' => { 'value' => 'BK' }
      }

      Alma::ReadingList.expects(:get_items_for_reading_list).returns([citation])

      assert_no_difference('Item.count') do
        result = ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)
        assert_equal :ok, result[:status]
        assert_equal 0, result[:added_local]
        assert_equal 1, result[:failed_local]
        assert_equal 0, result[:removed_local]
      end
    end

    should 'normalize legacy item types before syncing' do
      legacy_item = create(:item, request: @request, alma_citation_id: nil)
      legacy_item.update_column(:item_type, 'BK')

      Alma::ReadingList.expects(:get_items_for_reading_list).returns([])
      Alma::AlmaSync.expects(:sync_item).never

      ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)

      assert_equal Item::TYPE_BOOK, legacy_item.reload.item_type
    end

    should 'return error status when Alma fetch raises' do
      Alma::ReadingList.expects(:get_items_for_reading_list).raises(StandardError.new('boom'))
      Rails.logger.expects(:error).with(regexp_matches(/ReadingListSync error/))

      result = ReadingListSync.sync!(request_id: @request.id, actor_id: @actor.id)
      assert_equal :error, result[:status]
      assert_equal 0, result[:removed_local]
    end

    should 'split isbns into primary and others' do
      service = ReadingListSync.new(@request, @actor)
      primary, others = service.send(:split_isbns, '978-0123456789; 0-321-14653-0, 012345678X')

      assert_equal '9780123456789', primary
      assert_includes others, '0321146530'
      assert_includes others, '012345678X'
    end
  end
end
