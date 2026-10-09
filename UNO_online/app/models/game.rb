class Game < ApplicationRecord
  # Доменные ошибки — контроллер превращает их в понятные пользователю сообщения
  class Error < StandardError; end
  class RoomFull < Error; end
  class GameInProgress < Error; end
  class NotAPlayer < Error; end

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
  # games.current_player_id ссылается на players, а players — на games:
  # перед удалением комнаты нужно разорвать эту ссылку, иначе FK не даст удалить игроков
  before_destroy :clear_current_player, prepend: true

  scope :publicly_listed, -> { where(visibility: "public").order(created_at: :desc) }

  STATUSES.each do |name|
    define_method(:"#{name}?") { status == name }
  end

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

  # Добавляет игрока в комнату. Повторный вход уже состоящего игрока — не ошибка.
  # Блокировка строки комнаты защищает от гонки за последнее свободное место.
  def add_player!(user)
    with_lock do
      players.find_by(user: user) || begin
        raise GameInProgress if playing?
        raise RoomFull if full?

        players.create!(user: user, position: next_position)
      end
    end
  end

  # Переключает готовность игрока; если готовы все — партия стартует.
  def toggle_ready!(user)
    with_lock do
      player = players.find_by(user: user)
      raise NotAPlayer unless player

      player.update!(ready: !player.ready)
      start! if waiting? && all_ready?
      player
    end
  end

  # Убирает игрока из комнаты и разруливает последствия:
  # — если ушёл хост, право переходит следующему по позиции игроку
  # — если ушёл последний игрок, комната удаляется целиком
  # — если во время игры остался ровно один игрок — он побеждает техническим
  #   образом (все соперники сдались), комната возвращается в лобби
  # — оставшимся игрокам позиции уплотняются (0..n-1, без дыр)
  def remove_player!(user)
    with_lock do
      player = players.find_by(user: user)
      settle_after_leaving!(player) if player
    end
  end

  private

  def settle_after_leaving!(player)
    was_host = host_id == player.user_id
    update!(current_player: nil) if current_player_id == player.id
    player.destroy!
    reload

    if players.none?
      destroy!
    else
      reassign_host! if was_host
      reassign_positions!
      conclude_by_forfeit! if playing? && players.one?
    end
  end

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

  def clear_current_player
    update_column(:current_player_id, nil) if current_player_id
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
