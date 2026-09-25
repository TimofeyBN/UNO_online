class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :position, null: false
      t.jsonb :hand, null: false, default: []
      t.boolean :has_called_uno, null: false, default: false

      t.timestamps
    end

    add_index :players, [:game_id, :user_id], unique: true
    add_index :players, [:game_id, :position], unique: true
  end
end
