class Player < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validates :position, presence: true, uniqueness: { scope: :game_id }
  validates :user_id, uniqueness: { scope: :game_id, message: "уже участвует в этой игре" }
end
