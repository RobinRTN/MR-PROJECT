Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  root to: "pages#home"
  get 'profile', to: 'pages#profile'
  get '/disponibilites', to: 'bookings#disponibilites'
  get '/reservation/:id', to: 'bookings#reservation'

  resources :bookings do  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
    member do
      put :confirm
      put :refuse
    end
  end
  resources :clients
  resources :formules
  resources :packages

  # Defines the root path route ("/")
  # root "articles#index"
end
