ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    PASSWORD = "123456"

    # Создаёт пользователя. Email строится из имени, поэтому имена в тесте должны быть разными.
    def create_user(name)
      User.create!(name: name, email: "#{name}@example.com", password: PASSWORD)
    end

    # Создаёт комнату, в которой пока один игрок — её создатель (хост).
    # Остальных добавляем в тесте: game.add_player!(user)
    def create_game(host, status: "waiting", max_players: 4, visibility: "public")
      game = Game.new(host: host, status: status, max_players: max_players, visibility: visibility)
      game.players.build(user: host, position: 0)
      game.save!
      game
    end
  end
end

class ActionDispatch::IntegrationTest
  # Входит в аккаунт так же, как это делает форма на странице /login
  def sign_in(user)
    post login_path, params: { email: user.email, password: PASSWORD }
  end
end
