require "test_helper"

class Uno::DeckTest < ActiveSupport::TestCase
  test "в колоде 108 карт" do
    assert_equal 108, Uno::Deck.build.size
  end

  test "на каждый цвет приходится 25 карт" do
    Uno::Card::COLORS.each do |color|
      assert_equal 25, Uno::Deck.build.count { |card| card["color"] == color }
    end
  end

  test "«чёрных» карт по 4 каждого вида, цвета у них нет" do
    wilds = Uno::Deck.build.select { |card| Uno::Card.wild?(card) }

    assert_equal 4, wilds.count { |card| card["value"] == "wild" }
    assert_equal 4, wilds.count { |card| card["value"] == "wild_draw4" }
    assert wilds.all? { |card| card["color"].nil? }
  end

  test "ходить можно картой того же цвета, того же значения или «чёрной»" do
    top = Uno::Card.build("red", "5")

    assert Uno::Card.playable?(Uno::Card.build("red", "9"), top)
    assert Uno::Card.playable?(Uno::Card.build("blue", "5"), top)
    assert Uno::Card.playable?(Uno::Card.build(nil, "wild"), top)
    assert_not Uno::Card.playable?(Uno::Card.build("blue", "9"), top)
  end
end
