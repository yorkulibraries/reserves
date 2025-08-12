# frozen_string_literal: true

require 'test_helper'

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @_request = create(:request, status: Request::INPROGRESS)

    @user = create(:user, admin: true, role: User::MANAGER_ROLE)
    log_user_in(@user)
  end

  should 'list all items for request' do
    items = create_list(:item, 2, request: @_request)

    items.each_with_index do |item, index|
      Audited::Audit.create!(
        auditable_id: @_request.id, 
        auditable_type: "Request", 
        associated_id: item.id, 
        associated_type: "item", 
        action: "note",
        comment: "Note #{index + 1}",
        user: @user
      )
    end

    @notes = {}

    @_request.items.each do |item|
      @notes[item.id] = Audited::Audit.where(
        auditable_id: @_request.id,
        auditable_type: "Request",
        associated_id: item.id,
        associated_type: "item",
        action: "note"
      )
    end

    get request_items_path(@_request)
    assert_response :success

    items.each do |item|
      has_notes = Audited::Audit.exists?(
        auditable_id: @_request.id,
        auditable_type: "Request",
        associated_id: item.id,
        associated_type: "item",
        action: "note"
      )
  
      expected_text = has_notes ? "⚠️" : ""
  
      assert_select "#notes-icon-#{item.id}", text: expected_text, 
                    message: "Notes icon should be #{has_notes ? 'present' : 'absent'} for item #{item.id}"
    end


  end

  should 'show new item form' do
    get new_request_item_path(@_request.id)
    assert_response :success
  end

  should 'create a new item' do
    assert_difference('Item.count') do
      post request_items_path(@_request), params: { item: attributes_for(:item).except(:request) }
      item = get_instance_var(:item)
      assert_equal 0, item.errors.size, "Should be no errors, #{item.errors.messages}"
      assert_redirected_to request_item_path(@_request, item)
    end
  end

  should 'create a new item with other_isbn_issn' do
    assert_difference('Item.count') do
      post request_items_path(@_request), params: { 
        item: attributes_for(:item, other_isbn_issn: '1234-5678').except(:request) 
      }
      item = get_instance_var(:item)
      assert_equal 0, item.errors.size, "Should be no errors, #{item.errors.messages}"
      assert_redirected_to request_item_path(@_request, item)
      assert_equal '1234-5678', item.other_isbn_issn, 'other_isbn_issn should match'
    end
  end

  should 'send en email to location email, after item created, if enabled' do
    @_request.location.setting_bcc_location_on_new_item = true
    @_request.location.save

    assert_enqueued_emails 1 do
      post request_items_path(@_request), params: { item: attributes_for(:item).except(:request) }
    end
  end

  should 'show item details' do
    item = create(:item, request: @_request)

    get request_item_path(@_request, item)
    assert_response :success
  end

  should 'show edit form' do
    item = create(:item, request: @_request)

    get edit_request_item_path(@_request, item)
    assert_response :success
  end

  should 'update an existing item' do
    item = create(:item, request: @_request)
    old_title = item.title

    patch request_item_path(@_request, item), params: { item: { title: 'New Title' } }
    item = get_instance_var(:item)
    assert_equal 0, item.errors.size, 'Should be no errors'
    assert_response :redirect
    assert_redirected_to request_item_path(@_request, item)

    assert_not_equal old_title, item.title, 'Old title is not there'
    assert_equal 'New Title', item.title, 'Title was updated'
  end

  should 'destroy not item' do
    item = create(:item, request: @_request)

    assert_no_difference('Item.count') do
      delete request_item_path(@_request, item)
    end

    assert_redirected_to request_path(@_request)
  end

  ## ADDITIONAL ACTIONS TESTS ##

  # should 'change request status to open if new item is added' do
  #   request = create(:request, status: Request::INPROGRESS)
  #   post request_items_path(@_request), params: { item: attributes_for(:item).except(:request) }
  #   r = get_instance_var(:request)
  #   assert_equal Request::OPEN, r.status, 'Status should be set to open'
  # end

  should 'request status should remain in progress when new item is added' do
    request = create(:request, status: Request::INPROGRESS)
    post request_items_path(@_request), params: { item: attributes_for(:item).except(:request) }
    r = get_instance_var(:request)
    assert_equal Request::INPROGRESS, r.status, 'Status should in progress'
  end

  should 'change status' do
    item = create(:item, status: Item::STATUS_NOT_READY, request: @_request)

    get change_status_request_item_path(@_request, item), params: { status: Item::STATUS_READY }
    assert_redirected_to @_request
    i = get_instance_var(:item)
    assert_equal Item::STATUS_READY, i.status, 'Status should change to ready'

    get change_status_request_item_path(@_request, item), params: { status: Item::STATUS_NOT_READY }
    i = get_instance_var(:item)
    assert_equal Item::STATUS_NOT_READY, i.status, 'Status should change to not ready'
  end

  should 'only change status to DELETED if request is REMOVED' do
    request = create(:request, status: Request::REMOVED)
    item = create(:item, request: request)

    get change_status_request_item_path(request, item), params: { status: Item::STATUS_DELETED }
    assert_redirected_to request, 'Should go back to request'
    i = get_instance_var(:item)
    assert_equal Item::STATUS_DELETED, i.status, 'Status should be changed to DELETED'

    [Request::COMPLETED, Request::OPEN, Request::INPROGRESS, Request::CANCELLED].each do |s|
      r = create(:request, status: s)
      i = create(:item, request: r)
      get change_status_request_item_path(r, i), params: { status: Item::STATUS_DELETED }
      _i = get_instance_var(:item)
      assert_not_equal Item::STATUS_DELETED, _i.status, 'Status should be be DELETED'
    end
  end

  should 'not be able to change DELETED status' do
    request = create(:request, status: Request::REMOVED)
    item = create(:item, request: request, status: Item::STATUS_DELETED)

    get change_status_request_item_path(request, item), params: { status: Item::STATUS_READY }
    i = get_instance_var(:item)
    assert_equal Item::STATUS_DELETED, i.status, 'Status should still be DELETED'
  end

  should 'enqueue AddCitationJob on item create' do
    assert_enqueued_with(job: AddCitationJob) do
      post request_items_path(@_request), params: { item: attributes_for(:item).except(:request) }
    end
  end  

  should 'toggle item status between NOT_READY and READY' do
    item = create(:item, request: @_request, status: Item::STATUS_NOT_READY)
  
    get change_status_request_item_path(@_request, item)
    assert_equal Item::STATUS_READY, get_instance_var(:item).status
  
    get change_status_request_item_path(@_request, item)
    assert_equal Item::STATUS_NOT_READY, get_instance_var(:item).status
  end
  

  should 're-render edit template if update fails' do
    item = create(:item, request: @_request)
  
    patch request_item_path(@_request, item), params: { item: { title: '' } }
  
    assert_response :success
    assert_template :edit
  end
  

  should 're-render new template if item creation fails' do
    invalid_attrs = attributes_for(:item, title: nil).except(:request) # Assume title is required
  
    assert_no_difference('Item.count') do
      post request_items_path(@_request), params: { item: invalid_attrs }
    end
  
    assert_response :success
    assert_template :new
  end  

  should 'enqueue AddCitationJob on item creation' do
    assert_enqueued_with(job: AddCitationJob) do
      post request_items_path(@_request), params: { item: attributes_for(:item).except(:request) }
    end
  end

  should 'call Alma::ReadingList.delete_citation on destroy if alma_citation_id is present and successful' do
    item = create(:item, request: @_request, alma_citation_id: 'CITE123')
    @_request.update!(alma_course_id: 'COURSE123', alma_reading_list_id: 'LIST123')

    Alma::ReadingList.expects(:delete_citation)
                     .with(course_id: 'COURSE123', reading_list_id: 'LIST123', citation_id: 'CITE123')
                     .returns(true)

    assert_no_difference('Item.count') do
      delete request_item_path(@_request, item)
    end
    
    item.reload
    assert_equal Item::STATUS_DELETED, item.status
                    
  end

  should 'destroy item even if Alma citation deletion fails' do
    item = create(:item, request: @_request, alma_citation_id: 'FAKE_CITATION')
  
    Alma::ReadingList.expects(:delete_citation).returns(false)
  
    assert_no_difference('Item.count') do
      delete request_item_path(@_request, item), xhr: true
      item.reload
      assert_equal 'FAKE_CITATION', item.alma_citation_id, 'Citation ID should not be cleared on failure'
    end
  
    assert_response :success
    assert_match "$(\"#item_#{item.id}", @response.body
  end   

  should 'not call Alma API on destroy if alma_citation_id is blank' do
    item = create(:item, request: @_request, alma_citation_id: nil)
    Alma::ReadingList.expects(:delete_citation).never

    assert_no_difference('Item.count') do
      delete request_item_path(@_request, item)
    end
    
    item.reload
    assert_equal Item::STATUS_DELETED, item.status    
  end
end
