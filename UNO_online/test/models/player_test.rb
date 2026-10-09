require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  setup do
    @anna = create_user("anna")
    @boris = create_user("boris")
    @game = create_game(@anna) # anna уже сидит на позиции 0
  end

  test "новый игрок по умолчанию не готов" do
    assert_not @game.players.first.ready?
  end

  test "один пользователь не может войти в одну комнату дважды" do
    duplicate = @game.players.build(user: @anna, position: 1)
    assert_not duplicate.valid?
  end

  test "два игрока не могут занимать одну позицию за столом" do
    clash = @game.players.build(user: @boris, position: 0)
    assert_not clash.valid?
  end
end
