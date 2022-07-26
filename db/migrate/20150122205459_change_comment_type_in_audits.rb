class ChangeCommentTypeInAudits < ActiveRecord::Migration
  def up
    change_column :audits, :comment, :text
  end

  def down
    change_column :audits, :comment, :string
  end
end
