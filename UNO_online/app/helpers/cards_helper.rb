module CardsHelper
  SYMBOLS = {
    "skip" => "⊘", "reverse" => "⇄", "draw2" => "+2", "wild" => "★", "wild_draw4" => "+4"
  }.freeze

  COLOR_NAMES = {
    "red" => "Красный", "yellow" => "Жёлтый", "green" => "Зелёный", "blue" => "Синий"
  }.freeze

  # Что написано на карте: цифра или значок
  def card_symbol(card)
    SYMBOLS.fetch(card["value"], card["value"])
  end

  def color_name(color)
    COLOR_NAMES.fetch(color, color)
  end
end
