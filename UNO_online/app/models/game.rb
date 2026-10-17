class Game < ApplicationRecord
  # Доменные ошибки — контроллер превращает их в понятные пользователю сообщения
  class Error < StandardError; end
  class RoomFull < Error; end
  class GameInProgress < Error; end
  class NotAPlayer < Error; end
  class NotPlaying < Error; end

  STATUSES = %w[waiting playing finished].freeze
  DIRECTIONS = %w[clockwise counterclockwise].freeze
  VISIBILITIES = %w[public private].freeze
  PLAYERS_RANGE = (2..6)

  has_many :players, -> { order(:position) }, dependent: :destroy, inverse_of: :game
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

  # Главная страница подписана на поток "lobby" (ActionCable). Когда меняется то, что на ней видно
  # (появилась или исчезла публичная комната, изменился её статус), просим все главные обновиться.
  after_create_commit  { self.class.broadcast_lobby_refresh if visibility == "public" }
  after_update_commit  { self.class.broadcast_lobby_refresh if visibility == "public" && saved_change_to_status? }
  after_destroy_commit { self.class.broadcast_lobby_refresh if visibility == "public" }

  scope :publicly_listed, -> { where(visibility: "public").order(created_at: :desc) }

  def self.broadcast_lobby_refresh
    Turbo::StreamsChannel.broadcast_refresh_to("lobby")
  end

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

  # ---------- Лобби ----------

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
      start! if !playing? && all_ready?
      player
    end
  end

  # Начало партии: статус «идёт игра» + раздача карт
  def start!
    players.update_all(ready: false, has_called_uno: false)
    update!(status: "playing", winner: nil)
    deal!
  end

  # ---------- Игра ----------

  def play_card!(user, card_index, color: nil, count: 1)
    act_as(user) { |engine, index| engine.play(index, card_index, color: color, count: count) }
  end

  def draw_card!(user)
    act_as(user) { |engine, index| engine.draw(index) }
  end

  def call_uno!(user)
    act_as(user) { |engine, index| engine.call_uno(index) }
  end

  # Рассылает каждому игроку его вариант стола (свои карты видны, чужие — только количество).
  # Приходит в браузер через ActionCable (Turbo Streams) и заменяет блок #game_table.
  def broadcast_table
    players.reload.each do |player|
      Turbo::StreamsChannel.broadcast_replace_to(
        self, player.user,
        target: "game_table", partial: "games/table",
        locals: { game: self, viewer: player.user }
      )
    end
  end

  # Сообщает игрокам, что комнату удалили (вызывать до destroy)
  def broadcast_deleted
    players.includes(:user).each do |player|
      Turbo::StreamsChannel.broadcast_replace_to(
        self, player.user,
        target: "game_table",
        html: '<div id="game_table" class="table-result"><h2>Комната удалена создателем</h2><a class="btn btn--primary" href="/">На главную</a></div>'
      )
    end
  end

  # ---------- Выход игроков ----------

  # Убирает игрока из комнаты и разруливает последствия:
  # — если ушёл хост, право переходит следующему по позиции игроку
  # — если ушёл последний игрок, комната удаляется целиком
  # — если во время игры остался ровно один игрок — он побеждает техническим
  #   образом (все соперники сдались), комната возвращается в лобби
  # — если ушёл игрок, чей сейчас ход, ход получает следующий
  # — оставшимся игрокам позиции уплотняются (0..n-1, без дыр)
  def remove_player!(user)
    was_playing = false

    with_lock do
      was_playing = playing?
      player = players.find_by(user: user)
      settle_after_leaving!(player) if player
    end

    broadcast_table if was_playing && !destroyed?
  end

  private

  # ---------- Связка с движком правил (Uno::Engine) ----------

  # Выполняет ход игрока: достаёт состояние из БД, отдаёт движку, сохраняет результат.
  def act_as(user)
    with_lock do
      raise NotPlaying unless playing?

      engine, list = load_engine
      index = list.index { |player| player.user_id == user.id }
      raise NotAPlayer unless index

      yield engine, index
      save_engine!(engine, list)
    end

    broadcast_table
  end

  def deal!
    list = players.reload.to_a
    save_engine!(Uno::Engine.start(list.size), list)
  end

  def load_engine
    list = players.reload.to_a
    engine = Uno::Engine.new(
      hands: list.map(&:hand),
      draw_pile: deck_state || [],
      discard_pile: discard_pile,
      top_card: top_card,
      direction: direction,
      current: list.index { |player| player.id == current_player_id } || 0,
      uno_called: list.map(&:has_called_uno),
      pending_draw: pending_draw
    )
    [ engine, list ]
  end

  def save_engine!(engine, list)
    list.each_with_index do |player, index|
      player.update!(hand: engine.hands[index], has_called_uno: engine.uno_called[index])
    end

    finished = !engine.winner.nil?
    update!(
      top_card: engine.top_card,
      deck_state: engine.draw_pile,
      discard_pile: engine.discard_pile,
      pending_draw: engine.pending_draw,
      direction: engine.direction,
      current_player: finished ? nil : list[engine.current],
      status: finished ? "finished" : status,
      winner: finished ? list[engine.winner].user : winner
    )
    players.update_all(ready: false) if finished
  end

  # ---------- Выход игрока ----------

  def settle_after_leaving!(player)
    was_host = host_id == player.user_id
    was_current = current_player_id == player.id
    leaver_index = players.to_a.index(player)
    leaver_hand = player.hand

    update!(current_player: nil, pending_draw: 0) if was_current # штраф ушедшего не переносим
    player.destroy!
    reload

    if players.none?
      destroy!
      return
    end

    reassign_host! if was_host
    reassign_positions!
    return unless playing?

    if players.one?
      conclude_by_forfeit!
    else
      update!(discard_pile: discard_pile + leaver_hand) # карты ушедшего уходят в сброс
      pass_turn_after_leaving!(leaver_index) if was_current
    end
  end

  # Ход ушедшего игрока получает тот, кто занял его место за столом
  def pass_turn_after_leaving!(leaver_index)
    list = players.to_a
    index = direction == "clockwise" ? leaver_index % list.size : (leaver_index - 1) % list.size
    update!(current_player: list[index])
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
      deck_state: [],
      discard_pile: [],
      pending_draw: 0
    )

    players.update_all(ready: false, hand: [], has_called_uno: false)
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
