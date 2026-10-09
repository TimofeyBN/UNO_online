require "test_helper"

class GamesTest < ActionDispatch::IntegrationTest
  setup do
    @anna = create_user("anna")
    @boris = create_user("boris")
    sign_in @anna # дальше все запросы выполняются от имени anna
  end

  #             Создание комнаты

  test "создание комнаты: создатель становится хостом и первым игроком" do
    post games_path, params: { visibility: "public", max_players: 3 }

    game = Game.last
    assert_redirected_to game_path(game)
    assert_equal @anna, game.host
    assert_equal 3, game.max_players
    assert_equal [ @anna ], game.users.to_a
  end

  test "недопустимое число игроков: комната не создаётся" do
    assert_no_difference("Game.count") do
      post games_path, params: { visibility: "public", max_players: 9 }
    end

    assert_redirected_to root_path
  end

  test "на главной видны публичные комнаты, приватные скрыты" do
    public_game = Game.create!(visibility: "public")
    private_game = Game.create!(visibility: "private")

    get root_path

    assert_includes response.body, public_game.code
    assert_not_includes response.body, private_game.code
  end

  #             Вход по коду

  test "вход по коду добавляет игрока в комнату" do
    game = create_game(@boris, visibility: "private")

    post join_games_path, params: { code: game.code }

    assert_redirected_to game_path(game)
    assert_includes game.users, @anna
  end

  test "неизвестный код: сообщение об ошибке" do
    post join_games_path, params: { code: "ZZZZZZ" }

    assert_redirected_to root_path
    assert_equal "Комната с таким кодом не найдена", flash[:alert]
  end

  test "в заполненную комнату войти нельзя" do
    clara = create_user("clara")
    game = create_game(@boris, max_players: 2)
    game.add_player!(clara)

    post join_games_path, params: { code: game.code }

    assert_redirected_to root_path
    assert_equal "Комната уже заполнена", flash[:alert]
    assert_not_includes game.users, @anna
  end

  test "в комнату, где идёт игра, войти нельзя" do
    clara = create_user("clara")
    game = create_game(@boris)
    game.add_player!(clara)
    game.update!(status: "playing")

    post join_games_path, params: { code: game.code }

    assert_redirected_to root_path
    assert_not_includes game.users, @anna
  end

  #             Лобби

  test "участник комнаты видит лобби" do
    game = create_game(@boris)
    game.add_player!(@anna)

    get game_path(game)

    assert_response :success
  end

  test "не участник комнаты лобби не видит" do
    game = create_game(@boris)

    get game_path(game)

    assert_redirected_to root_path
  end

  test "когда все нажали «Готов», игра стартует и открывается страница игры" do
    game = create_game(@boris)
    game.add_player!(@anna)
    game.toggle_ready!(@boris) # boris уже готов

    post ready_game_path(game) # anna нажимает «Готов»

    assert_redirected_to play_game_path(game)
    assert game.reload.playing?
  end

  #             Выход и удаление

  test "игрок может выйти из комнаты" do
    game = create_game(@boris)
    game.add_player!(@anna)

    post leave_game_path(game)

    assert_redirected_to root_path
    assert_not_includes game.reload.users, @anna
  end

  test "хост может удалить комнату" do
    game = create_game(@anna) # anna — хост

    assert_difference("Game.count", -1) do
      delete game_path(game)
    end

    assert_redirected_to root_path
  end

  test "не хост удалить комнату не может" do
    game = create_game(@boris) # хост — boris
    game.add_player!(@anna)

    assert_no_difference("Game.count") do
      delete game_path(game)
    end

    assert_equal "Удалить комнату может только создатель", flash[:alert]
  end

  test "открытие уже удалённой комнаты не ломает сайт, а возвращает на главную" do
    game = create_game(@anna)
    game.destroy!

    get game_path(game.id)

    assert_redirected_to root_path
  end
end
