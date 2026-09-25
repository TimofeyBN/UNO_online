class AddCurrentPlayerForeignKeyToGames < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :games, :players, column: :current_player_id
    add_index :games, :current_player_id
  end
end
