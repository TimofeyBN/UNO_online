require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @tim = create_user("tim")
  end

  test "вход с верным паролем: id пользователя попадает в session" do
    sign_in @tim

    assert_redirected_to root_path
    assert_equal @tim.id, session[:user_id]
  end

  test "вход с неверным паролем отклоняется" do
    post login_path, params: { email: @tim.email, password: "неверный-пароль" }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "главная страница без входа перенаправляет на страницу входа" do
    get root_path
    assert_redirected_to login_path
  end

  test "после выхода главная снова недоступна" do
    sign_in @tim
    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end
end
