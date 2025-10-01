# frozen_string_literal: true

require 'test_helper'

module Alma
  class UserTest < ActiveSupport::TestCase

    should 'return nil when user lookup by primary id fails' do
      response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, 'missing')

      User.expects(:perform_get_request).returns(response)
      assert_nil User.find_by_primary_id(primary_id: '123')
    end

    should 'parse user data when lookup by primary id succeeds' do
      body = { 'primary_id' => '123', 'first_name' => 'Ann' }.to_json
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)

      User.expects(:perform_get_request).returns(response)
      result = User.find_by_primary_id(primary_id: '123')
      assert_equal 'Ann', result['first_name']
    end

    should 'return empty results when searching with blank names' do
      assert_equal [], User.search_by_name(first_name: '', last_name: 'Smith')
      assert_equal [], User.search_by_name(first_name: 'Ann', last_name: '')
    end

    should 'parse user list on successful search' do
      response_body = {
        'user' => [
          { 'primary_id' => '123', 'first_name' => 'Ann', 'last_name' => 'Smith' }
        ]
      }.to_json

      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, response_body)

      User.expects(:perform_get_request).returns(response)

      result = User.search_by_name(first_name: 'Ann', last_name: 'Smith')
      assert_equal 1, result.size
      assert_equal '123', result.first['primary_id']
    end

    should 'return status none when no candidates found' do
      User.stubs(:search_by_name).returns([])

      result = User.find_best_by_name(first_name: 'Ann', last_name: 'Smith')
      assert_equal :none, result[:status]
    end

    should 'return best match when a single candidate scores highest' do
      candidate = {
        'primary_id' => 'ABC',
        'first_name' => 'Ann',
        'last_name' => 'Smith',
        'user_roles' => { 'user_role' => [{ 'role_type' => { 'value' => 'INSTRUCTOR' } }] },
        'user_group' => { 'value' => 'FACULTY' }
      }

      User.stubs(:search_by_name).returns([candidate])

      result = User.find_best_by_name(first_name: 'Ann', last_name: 'Smith')
      assert_equal :ok, result[:status]
      assert_equal 'ABC', result[:user]['primary_id']
    end

    should 'surface ambiguity when multiple matches tie' do
      candidate1 = { 'primary_id' => 'A', 'first_name' => 'Ann', 'last_name' => 'Smith' }
      candidate2 = { 'primary_id' => 'B', 'first_name' => 'Ann', 'last_name' => 'Smith' }

      User.stubs(:search_by_name).returns([candidate1, candidate2])

      result = User.find_best_by_name(first_name: 'Ann', last_name: 'Smith')
      assert_equal :ambiguous, result[:status]
      assert_equal 2, Array(result[:candidates]).size
    end
  end
end
