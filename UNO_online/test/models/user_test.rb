require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "пользователь с правильными данными сохраняется" do
    user = User.new(name: "Тимофей", email: "tim@example.com", password: PASSWORD)
    assert user.valid?
  end

  test "без имени пользователь не сохраняется" do
    user = User.new(name: "", email: "tim@example.com", password: PASSWORD)
    assert_not user.valid?
  end

  test "email без символа @ не принимается" do
    user = User.new(name: "Тимофей", email: "tim.example.com", password: PASSWORD)
    assert_not user.valid?
  end

  test "email приводится к нижнему регистру и без пробелов" do
    user = User.create!(name: "Тимофей", email: "  TIM@Example.com ", password: PASSWORD)
    assert_equal "tim@example.com", user.email
  end

  test "email должен быть уникальным, регистр не важен" do
    create_user("tim") # email: tim@example.com
    second = User.new(name: "Другой", email: "TIM@example.com", password: PASSWORD)
    assert_not second.valid?
  end

  test "пароль короче 6 символов не принимается" do
    user = User.new(name: "Тимофей", email: "tim@example.com", password: "12345")
    assert_not user.valid?
  end

  test "пароль хранится в виде хеша, а не открытым текстом" do
    user = create_user("tim")
    assert_not_equal PASSWORD, user.password_digest
  end

  test "authenticate принимает верный пароль и отвергает неверный" do
    user = create_user("tim")
    assert user.authenticate(PASSWORD)
    assert_not user.authenticate("неверный-пароль")
  end
end
