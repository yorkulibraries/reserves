# db/migrate/20250826135000_change_all_datetime_to_precision_6.rb
class ChangeAllDatetimeToPrecision6 < ActiveRecord::Migration[7.0]
  def change
    # Get all tables and their DATETIME columns
    datetime_columns = ActiveRecord::Base.connection.execute(<<-SQL
      SELECT TABLE_NAME, COLUMN_NAME
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE DATA_TYPE = 'datetime'
      AND TABLE_SCHEMA = DATABASE()
    SQL
    ).to_a

    datetime_columns.each do |table_name, column_name|
      change_column table_name.to_sym, column_name.to_sym, :datetime, precision: 6
    end
  end
end