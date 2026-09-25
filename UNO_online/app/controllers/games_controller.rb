class GamesController < ApplicationController
  before_action :require_login

  def index
    @games = Game.where(status: %w[waiting playing])
                 .order(created_at: :desc)
                 .includes(:players)
  end

  def create
    game = Game.new
    game.players.build(user: current_user, position: 0)

    if game.save
      redirect_to game
    else
      redirect_to root_path, alert: "Не удалось создать комнату, попробуйте ещё раз"
    end
  end

  def join
    game = Game.find_by(code: params[:code].to_s.upcase.strip)

    if game.nil?
      redirect_to root_path, alert: "Комната с таким кодом не найдена"
    elsif game.players.exists?(user: current_user)
      redirect_to game
    elsif game.full?
      redirect_to root_path, alert: "Комната уже заполнена"
    else
      game.players.create!(user: current_user, position: game.players.count)
      redirect_to game
    end
  end

  def show
    # Экран лобби/стола 
    @game = Game.find(params[:id])
  end
end
