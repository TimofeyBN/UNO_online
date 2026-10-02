class Game < ApplicationRecord
  STATUSES = %w[waiting playing finished].freeze
  DIRECTIONS = %w[clockwise counterclockwise].freeze
  VISIBILITIES = %w[public private].freeze
  PLAYERS_RANGE = (2..6)

  has_many :players, -> { order(:position) }, dependent: :destroy
  has_many :users, through: :players
  belongs_to :winner, class_name: "User", optional: true
  belongs_to :current_player, class_name: "Player", optional: true
  belongs_to :host, class_name: "User", optional: true

  validates :code, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :max_players, numericality: {
    only_integer: true,
    greater_than_or_equal_to: PLAYERS_RANGE.first,
    less_than_or_equal_to: PLAYERS_RANGE.last
  }

  before_validation :generate_code, on: :create

  def full?
    players.count >= max_players
  end

  def next_position
    (players.maximum(:position) || -1) + 1
  end

  # Готовы ли все к игре — минимум 2 игрока, и у каждого выставлен флаг ready
  def all_ready?
    players.size >= 2 && players.all?(&:ready?)
  end

  def start!
    update!(status: "playing")
  end

  # Убирает игрока из комнаты и разруливает последствия:
  # — если ушёл хост, право переходит следующему по позиции игроку
  # — если ушёл последний игрок, комната удаляется целиком
  # — если во время игры остался ровно один игрок — он побеждает техническим
  #   образом (все соперники сдались), комната возвращается в лобби
  # — оставшимся игрокам позиции уплотняются (0..n-1, без дыр)
  def remove_player!(user)
    player = players.find_by(user: user)
    return unless player

    was_host = host_id == user.id
    player.destroy!
    reload

    if players.none?
      destroy!
      return
    end

    reassign_host! if was_host
    reassign_positions!
    conclude_by_forfeit! if status == "playing" && players.one?
  end

  private

  # Все соперники разошлись — последний оставшийся объявляется победителем,
  # комната откатывается в лобби (можно сразу собрать новую партию)
  def conclude_by_forfeit!
    remaining_player = players.first

    update!(
      status: "waiting",
      winner: remaining_player.user,
      current_player: nil,
      top_card: nil,
      deck_state: nil
    )

    players.update_all(ready: false)
  end

  # code — короткий человекочитаемый идентификатор комнаты для входа
  # по ссылке/коду (используется и для публичных, и для приватных комнат)
  def generate_code
    return if code.present?

    self.code = loop do
      candidate = SecureRandom.alphanumeric(6).upcase
      break candidate unless Game.exists?(code: candidate)
    end
  end

  def reassign_host!
    successor = players.order(:position).first
    update!(host: successor.user)
  end

  def reassign_positions!
    players.order(:position).each_with_index do |player, index|
      player.update_column(:position, index) if player.position != index
    end
  end
end
