# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20210820131142) do

  create_table "acquisition_items", force: :cascade do |t|
    t.integer "item_id"
    t.integer "request_id"
    t.integer "requested_by_id"
    t.text "acquisition_reason"
    t.string "status", limit: 255
    t.integer "cancelled_by_id"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.integer "acquired_by_id"
    t.datetime "acquired_at"
    t.text "acquisition_notes"
    t.text "acquisition_source_type"
    t.text "acquisition_source_name"
    t.integer "list_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "acquisition_requests", force: :cascade do |t|
    t.integer "item_id"
    t.integer "requested_by_id"
    t.text "acquisition_reason"
    t.string "status", limit: 255
    t.integer "cancelled_by_id"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.integer "acquired_by_id"
    t.datetime "acquired_at"
    t.text "acquisition_notes"
    t.text "acquisition_source_type"
    t.text "acquisition_source_name"
    t.integer "list_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "location_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.text "message"
    t.string "audience", limit: 255
    t.integer "location_id"
    t.boolean "active", default: false
    t.integer "created_by_id"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type", limit: 255
    t.integer "associated_id"
    t.string "associated_type", limit: 255
    t.integer "user_id"
    t.string "user_type", limit: 255
    t.string "username", limit: 255
    t.string "action", limit: 255
    t.text "audited_changes"
    t.integer "version", default: 0
    t.text "comment", limit: 255
    t.string "remote_address", limit: 255
    t.datetime "created_at"
    t.string "request_uuid", limit: 255
    t.index ["associated_id", "associated_type"], name: "associated_index"
    t.index ["auditable_id", "auditable_type"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "courses", force: :cascade do |t|
    t.string "name", limit: 255
    t.string "code", limit: 255
    t.integer "student_count"
    t.string "instructor", limit: 255
    t.integer "created_by_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "code_year"
    t.string "code_faculty"
    t.string "code_subject"
    t.string "code_term"
    t.string "code_credits"
    t.string "code_section"
  end

  create_table "courses_faculties", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "courses_subjects", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "items", force: :cascade do |t|
    t.integer "request_id"
    t.string "metadata_source", limit: 255
    t.string "metadata_source_id", limit: 255
    t.string "title", limit: 255
    t.string "author", limit: 255
    t.string "isbn", limit: 255
    t.string "callnumber", limit: 255
    t.string "publication_date", limit: 255
    t.string "publisher", limit: 255
    t.string "description", limit: 255
    t.string "edition", limit: 255
    t.string "loan_period", limit: 255
    t.boolean "provided_by_requestor", default: false
    t.string "item_type", limit: 255
    t.string "copyright_options", limit: 255
    t.text "other_copyright_options"
    t.string "format", limit: 255
    t.text "url"
    t.string "status", limit: 255
    t.string "map_index_num", limit: 255
    t.string "journal_title", limit: 255
    t.string "volume", limit: 255
    t.string "page_number", limit: 255
    t.string "issue", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "ils_barcode"
    t.boolean "physical_copy_required", default: false
  end

  create_table "loan_periods", force: :cascade do |t|
    t.string "duration", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", limit: 255
    t.string "contact_email", limit: 255
    t.string "contact_phone", limit: 255
    t.text "address"
    t.boolean "is_deleted", default: false
    t.string "disallowed_item_types", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "setting_bcc_request_status_change", default: false
    t.string "ils_location_name"
    t.boolean "setting_bcc_location_on_new_item", default: false
    t.string "acquisitions_email"
  end

  create_table "requests", force: :cascade do |t|
    t.integer "requester_id"
    t.integer "course_id"
    t.integer "assigned_to_id"
    t.integer "reserve_location_id"
    t.date "requested_date"
    t.date "completed_date"
    t.date "cancelled_date"
    t.date "reserve_start_date"
    t.date "reserve_end_date"
    t.string "status", limit: 255
    t.boolean "removed_from_reserves", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "requester_email", limit: 255
    t.integer "rollover_parent_id"
    t.datetime "rolledover_at"
    t.datetime "removed_at"
    t.integer "removed_by_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "var", limit: 255, null: false
    t.text "value"
    t.integer "thing_id"
    t.string "thing_type", limit: 30
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["thing_type", "thing_id", "var"], name: "index_settings_on_thing_type_and_thing_id_and_var", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name", limit: 255
    t.string "email", limit: 255
    t.string "phone", limit: 255
    t.string "user_type", limit: 255
    t.string "role", limit: 255
    t.string "department", limit: 255
    t.string "office", limit: 255
    t.string "uid", limit: 255
    t.string "library_uid", limit: 255
    t.boolean "active", default: true
    t.boolean "admin", default: false
    t.integer "location_id"
    t.integer "created_by_id"
    t.datetime "last_login"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
