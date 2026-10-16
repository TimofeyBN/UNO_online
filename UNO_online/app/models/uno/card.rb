module Uno
  # Карта — обычный хэш: { "color" => "red", "value" => "5" }.
  # У «чёрных» карт (wild, wild_draw4) цвет пустой, пока игрок не выбрал его.
  module Card
    COLORS = %w[red yellow green blue].freeze
    NUMBERS = %w[0 1 2 3 4 5 6 7 8 9].freeze
    ACTIONS = %w[skip reverse draw2].freeze
    WILDS = %w[wild wild_draw4].freeze
    DRAWS = %w[draw2 wild_draw4].freeze # «штрафные» карты: +2 и +4

    def self.build(color, value)
      { "color" => color, "value" => value }
    end

    def self.wild?(card)
      WILDS.include?(card["value"])
    end

    def self.draw_card?(card)
      DRAWS.include?(card["value"])
    end

    # Ходить можно картой того же цвета, того же значения или «чёрной» картой.
    # Пока на столе висит штраф (+2/+4), отвечать можно только «штрафной» картой.
    def self.playable?(card, top_card, pending_draw: 0)
      return draw_card?(card) if pending_draw.positive?
      return true if wild?(card) || top_card.nil?

      card["color"] == top_card["color"] || card["value"] == top_card["value"]
    end
  end
end
