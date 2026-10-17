class Player < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :game_id }
  validates :user_id, uniqueness: { scope: :game_id, message: "уже участвует в этой игре" }

  # На главной у каждой публичной комнаты написано «2/4 игроков» — при входе и выходе обновляем её
  # (одним вызовом: два колбэка с одним именем метода перезаписали бы друг друга)
  after_commit :refresh_lobby, on: [ :create, :destroy ]

  private

  def refresh_lobby
    Game.broadcast_lobby_refresh if game&.visibility == "public"
  end
end
