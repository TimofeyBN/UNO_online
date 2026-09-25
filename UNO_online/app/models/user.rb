class User < ApplicationRecord
  has_secure_password

  has_many :players, dependent: :destroy
  has_many :games, through: :players

  before_validation { self.email = email.to_s.downcase.strip }

  validates :name, presence: true
  validates :email, presence: true,
                     uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP, message: "некорректный формат" }
  validates :password, length: { minimum: 6 }, allow_nil: true
end
