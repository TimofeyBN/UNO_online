class Game < ApplicationRecord
  MAX_PLAYERS = 4
  STATUSES = %w[waiting playing finished].freeze
  DIRECTIONS = %w[clockwise counterclockwise].freeze

  has_many :players, dependent: :destroy
  has_many :users, through: :players
  belongs_to :winner, class_name: "User", optional: true
  belongs_to :current_player, class_name: "Player", optional: true

  validates :code, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :direction, inclusion: { in: DIRECTIONS }

  before_validation :generate_code, on: :create

  def full?
    players.count >= MAX_PLAYERS
  end

  private

  # code — короткий человекочитаемый идентификатор комнаты для входа
  # по ссылке/коду
  def generate_code
    return if code.present?

    self.code = loop do
      candidate = SecureRandom.alphanumeric(6).upcase
      break candidate unless Game.exists?(code: candidate)
    end
  end
end
