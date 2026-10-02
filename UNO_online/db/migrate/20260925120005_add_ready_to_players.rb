class AddReadyToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :ready, :boolean, null: false, default: false
  end
end
