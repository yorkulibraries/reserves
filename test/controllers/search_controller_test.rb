# frozen_string_literal: true

require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, admin: true, role: User::MANAGER_ROLE)
    log_user_in(@user)
  end

  should 'search by id' do
    r = create(:request)

    get search_path, params: { q: r.id, type: "requests", search_type: 'request' }

    requests = get_instance_var(:requests)
    assert requests, 'Requests should not be nil'
    assert_equal 1, requests.size, 'Only one'
    assert_equal r.id, requests.first.id, 'Matching'
  end

  should "search by instructor name or course title" do
    c = create(:course, instructor: "John Terry", name: "Football Tacticts")
    r = create(:request, course: c)
    create_list(:request, 3)
  
    Course.reindex

    get search_path, params: {  q: "John", type: "requests", search_type: "course" }
  
    requests = get_instance_var(:requests)
    assert requests
    assert requests.size >= 1, "At least one match should be"
  
    get search_path, params: { q: "Football" }
    requests = get_instance_var(:requests)
    assert requests
    assert requests.size >- 1, "at least one match"
  end

  should "search by item name" do
    r = create(:request)
    i = create(:item, title: "Item Name Test", request: r)
    create_list(:request, 3)
  
    Item.reindex

    get search_path, params: {  q: "Item Name Test", type: "requests", search_type: 'item' }

    requests = get_instance_var(:requests)
    assert requests
    assert requests.size >= 1, "At least one match should be"
  end

  should "search by item author" do
    r = create(:request)
    i = create(:item, title: "Item Name Test", author: 'Item Author Test', request: r)
    create_list(:request, 3)
  
    Item.reindex

    get search_path, params: {  q: "Item Author Test", type: "requests", search_type: 'item' }

    requests = get_instance_var(:requests)
    assert requests
    assert requests.size >= 1, "At least one match should be"
  end

  should "search by item isbn" do
    r = create(:request)
    i = create(:item, title: "Item Name Test", isbn: '1234567890', request: r)
    create_list(:request, 3)
  
    Item.reindex

    get search_path, params: {  q: "1234567890", type: "requests", search_type: 'item' }

    requests = get_instance_var(:requests)
    assert requests
    assert requests.size >= 1, "At least one match should be"
  end

  should "search by item publisher" do
    r = create(:request)
    i = create(:item, title: "Item Name Test", publisher: 'Publisher Item Test', request: r)
    create_list(:request, 3)
  
    Item.reindex

    get search_path, params: {  q: "Publisher Item Test", type: "requests", search_type: 'item' }

    requests = get_instance_var(:requests)
    assert requests
    assert requests.size >= 1, "At least one match should be"
  end

  should "return an empty array if nothing is found" do
    Item.reindex
    Course.reindex

    get search_path, params: { q: "searching emptiness" }
  
    requests = get_instance_var(:requests)
    assert requests
    assert_equal 0, requests.size, "Should be nothing there"
  end
  

  # should 'return an request if found an item with specified id. Using [i: 2323] pattern' do
  #   i = create(:item)
  #   r = i.request

  #   get search_path, params: { q: "i: #{i.id}", type: "requests", search_type: 'request' }

  #   requests = get_instance_var(:requests)
  #   assert requests
  #   assert_equal 1, requests.size, 'Should be one only'
  #   assert_equal requests.first.id, r.id, 'Request ids are matched'
  # end
end
