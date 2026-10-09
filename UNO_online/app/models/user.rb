class User < ApplicationRecord
  has_secure_password

  has_many :players, dependent: :destroy
  has_many :games, through: :players
  has_many :hosted_games, class_name: "Game", foreign_key: :host_id, dependent: :nullify, inverse_of: :host
  has_many :won_games, class_name: "Game", foreign_key: :winner_id, dependent: :nullify, inverse_of: :winner

  before_validation { self.email = email.to_s.downcase.strip }

  validates :name, presence: true, length: { maximum: 50 }
  validates :email, presence: true,
                     uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP, message: "некорректный формат" }
  validates :password, length: { minimum: 6 }, allow_nil: true
end
