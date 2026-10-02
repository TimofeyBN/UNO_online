class GamesController < ApplicationController
  before_action :require_login
  before_action :set_game, only: %i[show destroy ready leave play]
  before_action :require_membership, only: %i[show ready leave play]

  def index
    @public_games = Game.where(visibility: "public")
                         .order(created_at: :desc)
                         .includes(:players)
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
    elsif game.players.exists?(user: current_user)
      redirect_to game
    elsif game.status == "playing"
      redirect_to root_path, alert: "В этой комнате сейчас идёт игра, дождитесь её окончания"
    elsif game.full?
      redirect_to root_path, alert: "Комната уже заполнена"
    else
      game.players.create!(user: current_user, position: game.next_position)
      redirect_to game
    end
  end

  def show
    redirect_to play_game_path(@game) and return if @game.status == "playing"

    # Защита от гонки: между проверкой членства (before_action) и рендером
    # вьюхи игрок мог успеть выйти параллельным запросом (например, авто-
    # обновление лобби сработало в ту же секунду, что и "Покинуть комнату")
    @my_player = @game.players.find_by(user: current_user)
    redirect_to root_path, alert: "Вы больше не в этой комнате" and return if @my_player.nil?
  end

  def play
    # Игровой стол — следующий этап разработки. Пока просто заглушка,
    # сюда редиректим всех игроков комнаты, когда статус становится "playing".
    # Если статус откатился назад (например, все соперники вышли и остался
    # один игрок — см. Game#conclude_by_forfeit!), возвращаем в лобби.
    redirect_to game_path(@game) and return if @game.status != "playing"
  end

  def ready
    player = @game.players.find_by(user: current_user)
    if player.nil?
      redirect_to root_path, alert: "Вы больше не в этой комнате" and return
    end

    player.update!(ready: !player.ready)
    @game.start! if @game.all_ready?

    redirect_to(@game.status == "playing" ? play_game_path(@game) : game_path(@game))
  end

  def leave
    @game.remove_player!(current_user)
    redirect_to root_path, notice: "Вы покинули комнату"
  end

  def destroy
    if @game.host_id == current_user.id
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
