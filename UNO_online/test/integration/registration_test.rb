require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  test "страница регистрации открывается" do
    get register_path
    assert_response :success
  end

  test "успешная регистрация создаёт пользователя и сразу входит в аккаунт" do
    assert_difference("User.count", 1) do
      post register_path, params: { user: { name: "Тимофей", email: "tim@example.com", password: "123456" } }
    end

    assert_redirected_to root_path
    assert_equal User.last.id, session[:user_id] # id пользователя положили в session
  end

  test "с коротким паролем регистрация отклоняется" do
    assert_no_difference("User.count") do
      post register_path, params: { user: { name: "Тимофей", email: "tim@example.com", password: "123" } }
    end

    assert_response :unprocessable_entity
  end

  test "с уже занятым email регистрация отклоняется" do
    create_user("tim") # email: tim@example.com

    assert_no_difference("User.count") do
      post register_path, params: { user: { name: "Другой", email: "tim@example.com", password: "123456" } }
    end

    assert_response :unprocessable_entity
  end
end
