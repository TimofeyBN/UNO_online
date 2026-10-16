require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @anna = create_user("anna")
    @boris = create_user("boris")
    @clara = create_user("clara")
  end

  # ---------- Создание комнаты ----------

  test "новая комната: значения по умолчанию и автоматический код из 6 символов" do
    game = Game.create!

    assert_equal "waiting", game.status
    assert_equal "public", game.visibility
    assert_equal 4, game.max_players
    assert_match(/\A[A-Z0-9]{6}\z/, game.code)
  end

  test "число игроков можно задать только от 2 до 6" do
    assert_not Game.new(max_players: 1).valid?
    assert Game.new(max_players: 2).valid?
    assert Game.new(max_players: 6).valid?
    assert_not Game.new(max_players: 7).valid?
  end

  test "видимость бывает только public или private" do
    assert Game.new(visibility: "private").valid?
    assert_not Game.new(visibility: "secret").valid?
  end

  test "publicly_listed возвращает только публичные комнаты" do
    public_game = Game.create!(visibility: "public")
    private_game = Game.create!(visibility: "private")

    assert_includes Game.publicly_listed, public_game
    assert_not_includes Game.publicly_listed, private_game
  end

  # ---------- Вход в комнату ----------

  test "add_player! добавляет игрока в конец очереди" do
    game = create_game(@anna)
    player = game.add_player!(@boris)

    assert_equal 1, player.position
    assert_equal 2, game.players.count
  end

  test "add_player! не пускает в заполненную комнату" do
    game = create_game(@anna, max_players: 2)
    game.add_player!(@boris)

    assert_raises(Game::RoomFull) { game.add_player!(@clara) }
  end

  test "add_player! не пускает в комнату, где идёт игра" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.update!(status: "playing")

    assert_raises(Game::GameInProgress) { game.add_player!(@clara) }
  end

  # ---------- Готовность и старт ----------

  test "игра не стартует, если игрок один, даже когда он готов" do
    game = create_game(@anna)
    game.toggle_ready!(@anna)

    assert game.reload.waiting?
  end

  test "игра не стартует, пока готовы не все" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.toggle_ready!(@anna)

    assert game.reload.waiting?
  end

  test "игра стартует, когда готовы все игроки" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.toggle_ready!(@anna)
    game.toggle_ready!(@boris)

    assert game.reload.playing?
  end

  # ---------- Выход игроков ----------

  test "когда уходит хост, права переходят следующему игроку" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.remove_player!(@anna)

    assert_equal @boris, game.reload.host
  end

  test "после выхода игрока позиции за столом пересчитываются без дыр" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.add_player!(@clara)
    game.remove_player!(@boris)

    assert_equal [ 0, 1 ], game.reload.players.map(&:position)
  end

  test "когда уходит последний игрок, комната удаляется" do
    game = create_game(@anna)
    game.remove_player!(@anna)

    assert_not Game.exists?(game.id)
  end

  test "если во время игры остался один игрок, он побеждает и комната становится лобби" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.add_player!(@clara)
    game.update!(status: "playing")

    game.remove_player!(@boris)
    assert game.reload.playing?, "осталось двое — игра продолжается"

    game.remove_player!(@clara)
    game.reload
    assert game.waiting?
    assert_equal @anna, game.winner
  end

  # ---------- Партия ----------

  # Запускает партию двух игроков (anna ходит первой) и подменяет руки и верхнюю карту,
  # чтобы результат хода был предсказуемым.
  def start_game(anna_hand:, boris_hand:, top: Uno::Card.build("red", "5"))
    game = create_game(@anna)
    game.add_player!(@boris)
    game.toggle_ready!(@anna)
    game.toggle_ready!(@boris) # оба готовы — партия началась
    game.players.find_by(user: @anna).update!(hand: anna_hand)
    game.players.find_by(user: @boris).update!(hand: boris_hand)
    game.update!(top_card: top)
    game
  end

  def red(value)
    Uno::Card.build("red", value)
  end

  test "при старте каждому раздаётся по 7 карт, на столе есть карта, ходит первый игрок" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.toggle_ready!(@anna)
    game.toggle_ready!(@boris)
    game.reload

    assert game.playing?
    assert_equal [ 7, 7 ], game.players.map { |player| player.hand.size }
    assert_not_nil game.top_card
    assert_equal @anna, game.current_player.user
  end

  test "ход картой: карта ложится на стол, ход переходит следующему" do
    game = start_game(anna_hand: [ red("9"), red("1"), red("3") ], boris_hand: [ red("2") ])
    game.play_card!(@anna, 0)
    game.reload

    assert_equal red("9"), game.top_card
    assert_equal 2, game.players.find_by(user: @anna).hand.size
    assert_equal @boris, game.current_player.user
  end

  test "ходить не в свой ход нельзя" do
    game = start_game(anna_hand: [ red("9"), red("1") ], boris_hand: [ red("2"), red("3") ])
    assert_raises(Uno::IllegalMove) { game.play_card!(@boris, 0) }
  end

  test "взять карту: в руке на одну больше, ход переходит дальше" do
    game = start_game(anna_hand: [ red("9"), red("1") ], boris_hand: [ red("2") ])
    game.draw_card!(@anna)
    game.reload

    assert_equal 3, game.players.find_by(user: @anna).hand.size
    assert_equal @boris, game.current_player.user
  end

  test "кто сыграл последнюю карту — победил, партия закончена" do
    game = start_game(anna_hand: [ red("9") ], boris_hand: [ red("2"), red("3") ])
    game.play_card!(@anna, 0)
    game.reload

    assert game.finished?
    assert_equal @anna, game.winner
    assert_nil game.current_player
  end

  test "после победы можно снова нажать «Готов» и начать новую партию" do
    game = start_game(anna_hand: [ red("9") ], boris_hand: [ red("2"), red("3") ])
    game.play_card!(@anna, 0)

    game.toggle_ready!(@anna)
    game.toggle_ready!(@boris)

    assert game.reload.playing?
    assert_equal [ 7, 7 ], game.players.map { |player| player.hand.size }
  end

  test "ходить нельзя, если партия не идёт" do
    game = create_game(@anna)
    assert_raises(Game::NotPlaying) { game.draw_card!(@anna) }
  end

  test "если уходит игрок, чей сейчас ход, ход получает следующий" do
    game = create_game(@anna)
    game.add_player!(@boris)
    game.add_player!(@clara)
    game.toggle_ready!(@anna)
    game.toggle_ready!(@boris)
    game.toggle_ready!(@clara) # ходит anna

    game.remove_player!(@anna)

    assert game.reload.playing?
    assert_equal @boris, game.current_player.user
  end

  test "штраф от +2 сохраняется в комнате и достаётся следующему игроку" do
    game = start_game(anna_hand: [ Uno::Card.build("red", "draw2"), red("1"), red("3") ], boris_hand: [ red("2") ])
    game.play_card!(@anna, 0)
    game.reload

    assert_equal 2, game.pending_draw
    assert_equal @boris, game.current_player.user

    game.draw_card!(@boris)
    game.reload

    assert_equal 0, game.pending_draw
    assert_equal 3, game.players.find_by(user: @boris).hand.size
  end

  test "одинаковые карты можно сыграть вместе" do
    game = start_game(anna_hand: [ red("9"), red("9"), red("1"), red("3") ], boris_hand: [ red("2") ])
    game.play_card!(@anna, 0, count: 2)

    assert_equal 2, game.reload.players.find_by(user: @anna).hand.size
  end
end
