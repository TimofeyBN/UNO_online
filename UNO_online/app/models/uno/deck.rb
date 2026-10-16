module Uno
  module Deck
    # Стандартная колода — 108 карт:
    # на каждый цвет: один «0», по два «1–9», по два skip / reverse / draw2 (25 карт);
    # плюс по 4 карты wild и wild_draw4.
    def self.build
      cards = []

      Card::COLORS.each do |color|
        cards << Card.build(color, "0")
        (Card::NUMBERS - [ "0" ] + Card::ACTIONS).each do |value|
          2.times { cards << Card.build(color, value) }
        end
      end

      Card::WILDS.each do |value|
        4.times { cards << Card.build(nil, value) }
      end

      cards
    end
  end
end
