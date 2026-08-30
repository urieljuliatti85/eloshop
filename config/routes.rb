Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    resources :products, only: %i[index show new create edit update] do
      member do
        patch :publish
        patch :unpublish
        patch :discontinue
      end

      resources :product_variants, path: "variantes", except: %i[index show]
      resources :personalization_options, path: "personalizacoes", except: %i[index show]
      resources :product_images, path: "imagens", only: %i[destroy]
    end

    resources :orders, only: %i[index show]
  end

  resources :products, only: %i[index show], param: :slug, path: "produtos"

  namespace :api do
    namespace :v1 do
      resources :products, only: %i[index show], param: :slug
    end
  end

  resource :cart, only: %i[show]
  resources :cart_items, only: %i[create update destroy]

  resource :contact, only: %i[new create]

  resources :customers, only: %i[new create]
  resource :customer_session, only: %i[new create destroy]
  resources :addresses, only: %i[new create]
  resources :orders, only: %i[new create show] do
    resource :payment, only: %i[new]
  end

  resource :wishlist, only: %i[show]
  resources :wishlist_items, only: %i[create destroy] do
    member { post :move_to_cart }
  end

  post "webhooks/fake_gateway", to: "payment_webhooks#create", as: :fake_gateway_webhook

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "products#index"
end
