class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :code, null: false
      t.string :status, null: false, default: "waiting"
      # ссылка на players.id добавляется отдельной миграцией ниже —
      # таблица players ещё не существует на этом шаге (циклическая зависимость)
      t.bigint :current_player_id
      t.string :direction, default: "clockwise"
      t.jsonb :top_card
      t.jsonb :deck_state
      t.references :winner, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :games, :code, unique: true
  end
end
