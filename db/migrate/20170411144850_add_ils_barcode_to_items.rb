class AddIlsBarcodeToItems < ActiveRecord::Migration
  def change
    add_column :items, :ils_barcode, :string
  end
end
