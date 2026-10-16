module Uno
  class IllegalMove < StandardError; end

  # Правила Uno. Класс ничего не знает про базу данных и Rails:
  # получает состояние партии, применяет ход и меняет это состояние.
  # Игроки обозначаются номером по порядку за столом: 0, 1, 2…
  class Engine
    HAND_SIZE = 7
    PENALTY = 2 # штраф, если не сказал «UNO!»

    attr_reader :hands, :draw_pile, :discard_pile, :top_card, :direction, :current, :winner, :uno_called, :pending_draw

    # Новая партия: тасуем колоду, раздаём по 7 карт, открываем первую карту
    def self.start(players_count, random: Random.new)
      pile = Deck.build.shuffle(random: random)
      hands = Array.new(players_count) { pile.shift(HAND_SIZE) }
      top_card = pile.delete_at(pile.index { |card| !Card.wild?(card) })

      new(hands: hands, draw_pile: pile, discard_pile: [], top_card: top_card,
          direction: "clockwise", current: 0, uno_called: Array.new(players_count, false), random: random)
    end

    def initialize(hands:, draw_pile:, discard_pile:, top_card:, direction:, current:, uno_called:, pending_draw: 0, random: Random.new)
      @hands = hands.map(&:dup)
      @draw_pile = draw_pile.dup
      @discard_pile = discard_pile.dup
      @top_card = top_card
      @direction = direction
      @current = current
      @uno_called = uno_called.dup
      @pending_draw = pending_draw # накопленный штраф от +2/+4, который ждёт текущего игрока
      @random = random
      @winner = nil
    end

    # Ход картой. color нужен только для «чёрных» карт.
    # count — сколько одинаковых карт (тот же цвет и значение) сыграть вместе.
    def play(player, card_index, color: nil, count: 1)
      ensure_turn!(player)
      hand = @hands[player]
      unless card_index.is_a?(Integer) && card_index.between?(0, hand.size - 1)
        raise IllegalMove, "Такой карты нет"
      end

      card = hand[card_index]
      unless Card.playable?(card, @top_card, pending_draw: @pending_draw)
        raise IllegalMove, @pending_draw.positive? ? "Сейчас можно ответить только +2 или +4" : "Эту карту нельзя сыграть"
      end
      raise IllegalMove, "Нужно выбрать цвет" if Card.wild?(card) && !Card::COLORS.include?(color)

      twins = hand.each_index.select { |index| hand[index] == card } # одинаковые карты, включая выбранную
      raise IllegalMove, "Столько одинаковых карт нет" unless count.is_a?(Integer) && count.between?(1, twins.size)

      chosen = ([ card_index ] + (twins - [ card_index ])).first(count)
      chosen.sort.reverse_each { |index| hand.delete_at(index) }

      @discard_pile << @top_card
      (count - 1).times { @discard_pile << card } # лишние одинаковые карты сразу уходят в сброс
      @top_card = Card.wild?(card) ? Card.build(color, card["value"]) : card
      apply_effect(player, card, count)
    end

    # Взять карту из колоды; ход переходит дальше.
    # Если на столе штраф (+2/+4) — берёт сразу весь накопленный штраф.
    def draw(player)
      ensure_turn!(player)
      draw_cards(player, @pending_draw.positive? ? @pending_draw : 1)
      @pending_draw = 0
      advance(1)
    end

    # «UNO!» можно сказать, когда осталось не больше двух карт
    def call_uno(player)
      raise IllegalMove, "UNO говорят, когда осталось не больше двух карт" if @hands[player].size > 2

      @uno_called[player] = true
    end

    private

    def ensure_turn!(player)
      raise IllegalMove, "Игра уже окончена" if @winner
      raise IllegalMove, "Сейчас не ваш ход" unless player == @current
    end

    def apply_effect(player, card, count)
      if @hands[player].empty?
        @winner = player
        return
      end

      # Осталась одна карта, а «UNO!» не сказал — штраф
      draw_cards(player, PENALTY) if @hands[player].size == 1 && !@uno_called[player]

      case card["value"]
      when "skip"
        # каждая карта пропускает одного игрока, но не больше, чем есть соперников
        advance([ count, @hands.size - 1 ].min + 1)
      when "reverse"
        flip_direction if count.odd?
        advance(@hands.size == 2 ? 0 : 1) # вдвоём reverse работает как skip: ходишь снова
      when "draw2"
        @pending_draw += 2 * count # штраф копится и переходит следующему игроку
        advance(1)
      when "wild_draw4"
        @pending_draw += 4 * count
        advance(1)
      else
        advance(1)
      end
    end

    def draw_cards(player, count)
      count.times do
        refill_draw_pile if @draw_pile.empty?
        break if @draw_pile.empty?

        @hands[player] << @draw_pile.shift
      end
      @uno_called[player] = false # карт стало больше — прежнее «UNO!» не считается
    end

    # Колода кончилась — тасуем сброс обратно (верхняя карта остаётся на столе)
    def refill_draw_pile
      cards = @discard_pile.map { |card| Card.wild?(card) ? Card.build(nil, card["value"]) : card }
      @draw_pile = cards.shuffle(random: @random)
      @discard_pile = []
    end

    def step
      @direction == "clockwise" ? 1 : -1
    end

    def next_player
      (@current + step) % @hands.size
    end

    def advance(steps)
      @current = (@current + step * steps) % @hands.size
    end

    def flip_direction
      @direction = @direction == "clockwise" ? "counterclockwise" : "clockwise"
    end
  end
end
