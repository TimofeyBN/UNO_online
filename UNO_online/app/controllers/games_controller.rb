class GamesController < ApplicationController
  before_action :require_login
  before_action :set_game, only: %i[show destroy ready leave play play_card draw_card call_uno]
  before_action :require_membership, only: %i[show ready leave play play_card draw_card call_uno]

  rescue_from Game::NotAPlayer do
    redirect_to root_path, alert: "Вы больше не в этой комнате"
  end

  def index
    @public_games = Game.publicly_listed.includes(:players)
  end

  def create
    game = Game.new(game_params)
    game.host = current_user
    game.players.build(user: current_user, position: 0)

    if game.save
      redirect_to game
    else
      redirect_to root_path, alert: game.errors.full_messages.to_sentence
    end
  end

  def join
    game = Game.find_by(code: params[:code].to_s.upcase.strip)

    if game.nil?
      redirect_to root_path, alert: "Комната с таким кодом не найдена"
    else
      game.add_player!(current_user)
      redirect_to game
    end
  rescue Game::GameInProgress
    redirect_to root_path, alert: "В этой комнате сейчас идёт игра, дождитесь её окончания"
  rescue Game::RoomFull
    redirect_to root_path, alert: "Комната уже заполнена"
  end

  def show
    return redirect_to(play_game_path(@game)) if @game.playing?

    # Защита от гонки: между проверкой членства (before_action) и рендером
    # вьюхи игрок мог успеть выйти параллельным запросом (например, авто-
    # обновление лобби сработало в ту же секунду, что и "Покинуть комнату")
    @my_player = @game.players.find_by(user: current_user)
    redirect_to root_path, alert: "Вы больше не в этой комнате" if @my_player.nil?
  end

  # Игровой стол. Дальше стол обновляется сам: каждый ход рассылается через ActionCable
  # (см. Game#broadcast_table и вьюху games/_table). Если партия закончилась, стол
  # показывает результат, а если комната откатилась в лобби — возвращаем в лобби.
  def play
    redirect_to game_path(@game) if @game.waiting?
  end

  # Ходы. В ответ ничего не отдаём (204): стол у всех игроков, включая самого
  # походившего, перерисуется через ActionCable.
  def play_card
    @game.play_card!(
      current_user, Integer(params[:card], exception: false),
      color: params[:color].presence, count: Integer(params[:count], exception: false) || 1
    )
    head :no_content
  rescue Uno::IllegalMove, Game::Error
    head :unprocessable_entity
  end

  def draw_card
    @game.draw_card!(current_user)
    head :no_content
  rescue Uno::IllegalMove, Game::Error
    head :unprocessable_entity
  end

  def call_uno
    @game.call_uno!(current_user)
    head :no_content
  rescue Uno::IllegalMove, Game::Error
    head :unprocessable_entity
  end

  def ready
    @game.toggle_ready!(current_user)
    redirect_to(@game.playing? ? play_game_path(@game) : game_path(@game))
  end

  def leave
    @game.remove_player!(current_user)
    redirect_to root_path, notice: "Вы покинули комнату"
  end

  def destroy
    if @game.host_id == current_user.id
      @game.broadcast_deleted
      @game.destroy!
      redirect_to root_path, notice: "Комната удалена"
    else
      redirect_to @game, alert: "Удалить комнату может только создатель"
    end
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def require_membership
    return if @game.players.exists?(user: current_user)

    redirect_to root_path, alert: "Вы не участник этой комнаты"
  end

  def game_params
    params.permit(:visibility, :max_players)
  end
end
