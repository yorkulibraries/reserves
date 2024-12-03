class RemoveMapsOnlyOption < ActiveRecord::Migration[7.0]
  def up
    LoanPeriod.where(duration: 'Display- Maps Only').delete_all
  end

  def down
    # Define the reversal of the above action if possible, or make it irreversible
    raise ActiveRecord::IrreversibleMigration, "Cannot restore removed rows"
  end
end