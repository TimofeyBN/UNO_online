class AddRoomSettingsToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :visibility, :string, null: false, default: "public"
    add_column :games, :max_players, :integer, null: false, default: 4
    add_reference :games, :host, foreign_key: { to_table: :users }, null: true

    add_index :games, :visibility
  end
end
