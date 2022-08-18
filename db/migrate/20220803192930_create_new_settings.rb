# frozen_string_literal: true

class CreateNewSettings < ActiveRecord::Migration[6.1]
  def self.up
    drop_table :settings
    create_table :settings do |t|
      t.string :var, null: false
      t.text :value, null: true
      t.timestamps
    end

    add_index :settings, %i[var], unique: true
  end

  def self.down
    drop_table :settings
  end
end