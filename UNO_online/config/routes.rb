Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "games#index"

  get "ui-kit", to: "pages#ui_kit"

  get "register", to: "registrations#new"
  post "register", to: "registrations#create"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :games, only: %i[index create show destroy] do
    member do
      post :ready
      post :leave
      get :play
    end
    collection do
      post :join
    end
  end
end
