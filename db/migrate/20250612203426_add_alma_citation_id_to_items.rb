class AddAlmaCitationIdToItems < ActiveRecord::Migration[7.0]
  def change
    add_column :items, :alma_citation_id, :string
  end
end
