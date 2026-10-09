class Player < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :game_id }
  validates :user_id, uniqueness: { scope: :game_id, message: "уже участвует в этой игре" }
end
