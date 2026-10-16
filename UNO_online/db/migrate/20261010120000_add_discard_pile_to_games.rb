class AddDiscardPileToGames < ActiveRecord::Migration[8.1]
  def change
    # Сброс (отыгранные карты): когда колода кончается, его перетасовывают обратно в колоду
    add_column :games, :discard_pile, :jsonb, null: false, default: []
  end
end
