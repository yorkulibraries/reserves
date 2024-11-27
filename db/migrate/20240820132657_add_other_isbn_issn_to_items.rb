class AddOtherIsbnIssnToItems < ActiveRecord::Migration[7.0]
  def change
    add_column :items, :other_isbn_issn, :string
  end
end
