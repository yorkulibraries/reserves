class CreateLoanPeriods < ActiveRecord::Migration
  def change
    create_table :loan_periods do |t|
      t.string :duration

      t.timestamps
    end
  end
end
