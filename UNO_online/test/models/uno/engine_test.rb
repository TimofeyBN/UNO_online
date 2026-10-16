require "test_helper"

class Uno::EngineTest < ActiveSupport::TestCase
  # Короткая запись карты: card("red", "5")
  def card(color, value)
    Uno::Card.build(color, value)
  end

  # Партия с заданными руками. По умолчанию на столе красная пятёрка, ходит игрок 0.
  def build_engine(hands, top: card("red", "5"), draw_pile: nil, **options)
    Uno::Engine.new(
      hands: hands,
      draw_pile: draw_pile || Array.new(20) { card("green", "1") },
      discard_pile: [],
      top_card: top,
      direction: "clockwise",
      current: 0,
      uno_called: Array.new(hands.size, false),
      **options
    )
  end

  # ---------- начало партии ----------

  test "в начале каждому игроку раздаётся по 7 карт" do
    engine = Uno::Engine.start(3)
    assert_equal [ 7, 7, 7 ], engine.hands.map(&:size)
  end

  test "в начале карты не теряются: 108 штук на руках, в колоде и на столе" do
    engine = Uno::Engine.start(4)
    total = engine.hands.sum(&:size) + engine.draw_pile.size + engine.discard_pile.size + 1
    assert_equal 108, total
  end

  test "первая карта на столе не «чёрная», ходит первый игрок" do
    engine = Uno::Engine.start(2)
    assert_not Uno::Card.wild?(engine.top_card)
    assert_equal 0, engine.current
  end

  # ---------- обычные ходы ----------

  test "нельзя ходить не в свой ход" do
    engine = build_engine([ [ card("red", "9") ], [ card("red", "1") ] ])
    assert_raises(Uno::IllegalMove) { engine.play(1, 0) }
  end

  test "нельзя сыграть карту другого цвета и другого значения" do
    engine = build_engine([ [ card("blue", "9"), card("red", "1") ], [ card("red", "2") ] ])
    assert_raises(Uno::IllegalMove) { engine.play(0, 0) }
  end

  test "после хода карта ложится на стол, а ход переходит следующему" do
    engine = build_engine([ [ card("red", "9"), card("red", "1"), card("red", "3") ], [ card("red", "2") ] ])
    engine.play(0, 0)

    assert_equal card("red", "9"), engine.top_card
    assert_equal 2, engine.hands[0].size
    assert_equal 1, engine.current
  end

  test "после последнего игрока ход возвращается к первому" do
    engine = build_engine([ [ card("red", "1"), card("red", "2") ], [ card("red", "3") ] ])
    engine.draw(0)
    engine.draw(1)
    assert_equal 0, engine.current
  end

  # ---------- особые карты ----------

  test "skip пропускает следующего игрока" do
    hands = [ [ card("red", "skip"), card("red", "1") ], [ card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)
    assert_equal 2, engine.current
  end

  test "reverse меняет направление хода" do
    hands = [ [ card("red", "reverse"), card("red", "1") ], [ card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)

    assert_equal "counterclockwise", engine.direction
    assert_equal 2, engine.current # ход пошёл назад: от 0 к последнему
  end

  test "reverse вдвоём работает как skip — ходишь снова" do
    hands = [ [ card("red", "reverse"), card("red", "1") ], [ card("red", "2") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)
    assert_equal 0, engine.current
  end

  test "wild: без выбора цвета сыграть нельзя" do
    engine = build_engine([ [ card(nil, "wild"), card("red", "1") ], [ card("red", "2") ] ])
    assert_raises(Uno::IllegalMove) { engine.play(0, 0) }
  end

  test "wild: выбранный цвет становится цветом на столе" do
    engine = build_engine([ [ card(nil, "wild"), card("red", "1") ], [ card("red", "2") ] ])
    engine.play(0, 0, color: "blue")

    assert_equal "blue", engine.top_card["color"]
    assert_equal 1, engine.current
  end

  # ---------- штраф +2 / +4 ----------

  test "draw2: штраф ждёт следующего игрока, ход переходит ему" do
    hands = [ [ card("red", "draw2"), card("red", "1") ], [ card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)

    assert_equal 2, engine.pending_draw
    assert_equal 1, engine.current
    assert_equal 1, engine.hands[1].size # карты он пока не брал
  end

  test "если ответить нечем, игрок берёт весь штраф и пропускает ход" do
    hands = [ [ card("red", "draw2"), card("red", "1") ], [ card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)
    engine.draw(1)

    assert_equal 3, engine.hands[1].size
    assert_equal 0, engine.pending_draw
    assert_equal 2, engine.current
  end

  test "на +2 можно ответить +2: штраф суммируется и переходит следующему" do
    hands = [ [ card("red", "draw2"), card("red", "1") ], [ card("blue", "draw2"), card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)
    engine.play(1, 0)

    assert_equal 4, engine.pending_draw
    assert_equal 2, engine.current

    engine.draw(2)
    assert_equal 5, engine.hands[2].size # была 1 карта + штраф 4
  end

  test "на +2 можно ответить +4" do
    hands = [ [ card("red", "draw2"), card("red", "1") ], [ card(nil, "wild_draw4"), card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)
    engine.play(1, 0, color: "green")

    assert_equal 6, engine.pending_draw
    assert_equal "green", engine.top_card["color"]
  end

  test "на +4 можно ответить +2, даже если цвет не совпадает" do
    hands = [ [ card(nil, "wild_draw4"), card("red", "1") ], [ card("red", "draw2"), card("red", "2") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0, color: "blue")
    engine.play(1, 0)

    assert_equal 6, engine.pending_draw
  end

  test "пока висит штраф, обычной картой ответить нельзя" do
    hands = [ [ card("red", "draw2"), card("red", "1") ], [ card("red", "2"), card("red", "9") ], [ card("red", "3") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)

    assert_raises(Uno::IllegalMove) { engine.play(1, 0) }
  end

  test "вдвоём штраф перебрасывается туда-обратно" do
    hands = [ [ card("red", "draw2"), card("red", "1"), card("red", "3") ],
              [ card("blue", "draw2"), card("red", "2"), card("red", "4") ] ]
    engine = build_engine(hands)
    engine.play(0, 0)
    engine.play(1, 0)

    assert_equal 4, engine.pending_draw
    assert_equal 0, engine.current

    engine.draw(0)
    assert_equal 6, engine.hands[0].size # было 2 карты + штраф 4
  end

  # ---------- сразу несколько одинаковых карт ----------

  test "одинаковые карты можно сыграть вместе: обе уходят из руки, ход переходит один раз" do
    hands = [ [ card("red", "9"), card("red", "9"), card("red", "1"), card("red", "3") ], [ card("red", "2") ] ]
    engine = build_engine(hands)
    engine.play(0, 0, count: 2)

    assert_equal 2, engine.hands[0].size
    assert_equal card("red", "9"), engine.top_card
    assert_equal 1, engine.current
  end

  test "нельзя сыграть вместе больше карт, чем одинаковых в руке" do
    hands = [ [ card("red", "9"), card("red", "9"), card("red", "1") ], [ card("red", "2") ] ]
    engine = build_engine(hands)
    assert_raises(Uno::IllegalMove) { engine.play(0, 0, count: 3) }
  end

  test "одинаковые — это одинаковый цвет и значение: красная и синяя девятки не пара" do
    hands = [ [ card("red", "9"), card("blue", "9"), card("red", "1"), card("red", "3") ], [ card("red", "2") ] ]
    engine = build_engine(hands)
    assert_raises(Uno::IllegalMove) { engine.play(0, 0, count: 2) }
  end

  test "если сыграть все одинаковые карты и рука пуста — победа" do
    engine = build_engine([ [ card("red", "9"), card("red", "9") ], [ card("red", "2") ] ])
    engine.play(0, 0, count: 2)
    assert_equal 0, engine.winner
  end

  test "два skip вместе пропускают двух соперников" do
    hands = [ [ card("red", "skip"), card("red", "skip"), card("red", "1"), card("red", "3") ],
              [ card("red", "2") ], [ card("red", "4") ], [ card("red", "5") ] ]
    engine = build_engine(hands)
    engine.play(0, 0, count: 2)
    assert_equal 3, engine.current # пропущены игроки 1 и 2
  end

  test "два draw2 вместе дают штраф 4" do
    hands = [ [ card("red", "draw2"), card("red", "draw2"), card("red", "1"), card("red", "3") ],
              [ card("red", "2") ], [ card("red", "4") ] ]
    engine = build_engine(hands)
    engine.play(0, 0, count: 2)

    assert_equal 4, engine.pending_draw
    assert_equal 1, engine.current
  end

  test "два reverse вместе направление не меняют" do
    hands = [ [ card("red", "reverse"), card("red", "reverse"), card("red", "1"), card("red", "3") ],
              [ card("red", "2") ], [ card("red", "4") ] ]
    engine = build_engine(hands)
    engine.play(0, 0, count: 2)

    assert_equal "clockwise", engine.direction
    assert_equal 1, engine.current
  end

  test "две «чёрные» карты wild играются вместе с одним выбором цвета" do
    hands = [ [ card(nil, "wild"), card(nil, "wild"), card("red", "1"), card("red", "3") ], [ card("red", "2") ] ]
    engine = build_engine(hands)
    engine.play(0, 0, color: "blue", count: 2)

    assert_equal "blue", engine.top_card["color"]
    assert_equal 2, engine.hands[0].size
  end

  # ---------- взять карту ----------

  test "взять карту: в руке на одну больше, ход переходит дальше" do
    engine = build_engine([ [ card("blue", "9") ], [ card("red", "2") ] ])
    engine.draw(0)

    assert_equal 2, engine.hands[0].size
    assert_equal 1, engine.current
  end

  test "когда колода кончилась, сброс тасуется обратно" do
    engine = build_engine([ [ card("blue", "9") ], [ card("red", "2") ] ], draw_pile: [])
    engine.instance_variable_set(:@discard_pile, [ card("green", "7"), card("green", "8") ])
    engine.draw(0)

    assert_equal 2, engine.hands[0].size
    assert_equal 1, engine.draw_pile.size
  end

  # ---------- UNO и победа ----------

  test "осталась одна карта, а «UNO!» не сказал — штраф 2 карты" do
    engine = build_engine([ [ card("red", "9"), card("red", "1") ], [ card("red", "2") ] ])
    engine.play(0, 0)
    assert_equal 3, engine.hands[0].size # была 1 карта + штраф 2
  end

  test "если «UNO!» сказал заранее, штрафа нет" do
    engine = build_engine([ [ card("red", "9"), card("red", "1") ], [ card("red", "2") ] ])
    engine.call_uno(0)
    engine.play(0, 0)
    assert_equal 1, engine.hands[0].size
  end

  test "«UNO!» нельзя сказать, пока в руке больше двух карт" do
    engine = build_engine([ [ card("red", "1"), card("red", "2"), card("red", "3") ], [ card("red", "4") ] ])
    assert_raises(Uno::IllegalMove) { engine.call_uno(0) }
  end

  test "кто первым избавился от всех карт — победил, и ходить больше нельзя" do
    engine = build_engine([ [ card("red", "9") ], [ card("red", "2") ] ])
    engine.play(0, 0)

    assert_equal 0, engine.winner
    assert_raises(Uno::IllegalMove) { engine.draw(1) }
  end
end
