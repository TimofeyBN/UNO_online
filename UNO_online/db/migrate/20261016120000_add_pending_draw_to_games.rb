class AddPendingDrawToGames < ActiveRecord::Migration[8.1]
  def change
    # Накопленный штраф от +2/+4, который должен взять (или перебить) текущий игрок
    add_column :games, :pending_draw, :integer, null: false, default: 0
  end
end
