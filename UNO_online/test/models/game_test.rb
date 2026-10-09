require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @anna = create_user("anna")
    @boris = create_user("boris")
    @clara = create_user("clara")
  end

  #             Создание комнаты

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

  #             Вход в комнату

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

  #             Готовность и старт

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

  #             Выход игроков

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
end
