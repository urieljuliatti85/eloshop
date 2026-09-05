Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root to: "dashboard#index"

    resources :sellers, only: %i[index show] do
      member do
        patch :approve
        patch :suspend
      end
    end

    resources :customers, only: %i[index show]

    # Gestão de quem administra a plataforma. Sem edição: trocar senha alheia
    # pelo painel é sequestro de conta — quem esquece usa a recuperação por
    # e-mail, que já existe.
    resources :admins, only: %i[index new create destroy]

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

    resources :reviews, only: %i[index] do
      member do
        patch :approve
        patch :reject
      end
    end

    resources :categories, except: %i[show]

    resources :coupons, except: %i[show]

    resources :orders, only: %i[index show] do
      member { post :refund }
    end
  end

  resources :products, only: :index, path: "produtos"
  # A vitrine pública do ateliê ocupa o mesmo prefixo que já identificava o
  # vendedor na URL do produto.
  resources :sellers, only: %i[index show], param: :slug, path: "artesaos"
  scope "artesaos/:seller_slug" do
    resources :products, only: :show, param: :slug, path: "produtos" do
      resources :reviews, only: :create
    end
  end
  get "produtos/:slug", to: "products#legacy_show", as: :legacy_product

  get "seja-um-artesao", to: "seller_registrations#new", as: :new_seller_registration
  post "seja-um-artesao", to: "seller_registrations#create", as: :seller_registration

  scope module: :seller_portal, as: :seller, path: "painel" do
    root to: "dashboard#index"
    get "mercado-pago/conectar", to: "mercado_pago_connections#create", as: :mercado_pago_connect
    get "mercado-pago/callback", to: "mercado_pago_connections#callback", as: :mercado_pago_callback
    delete "mercado-pago", to: "mercado_pago_connections#destroy", as: :mercado_pago_connection
    resources :products, except: :destroy do
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

  namespace :api do
    namespace :v1 do
      resources :products, only: :index
      scope "sellers/:seller_slug" do
        resources :products, only: :show, param: :slug
      end
    end
  end

  resource :cart, only: %i[show] do
    post :apply_coupon
    delete :remove_coupon
  end
  resources :cart_items, only: %i[create update destroy]

  resource :contact, only: %i[new create]

  # Atribuição das fotos de catálogo. CC BY e CC BY-SA exigem crédito
  # visível para quem publica a imagem — ver db/seeds/images/credits.yml.
  get "creditos", to: "credits#show", as: :credits

  resources :customers, only: %i[new create]
  resource :customer_session, only: %i[new create destroy]

  # Área do cliente: os destinos da conta sob um prefixo só, para o menu do
  # topo e o painel terem para onde apontar.
  scope "minha-conta", as: :account do
    root to: "accounts#show", as: :root
    resource :profile, only: %i[edit update], controller: "account_profiles", path: "cadastro"
  end

  # `new`/`create` já eram usados dentro do checkout; a área do cliente
  # acrescenta a gestão (listar, editar, excluir).
  resources :addresses, only: %i[index new create edit update destroy]
  resources :orders, only: %i[index new create show] do
    resource :payment, only: %i[new] do
      get :status
    end
  end

  resource :wishlist, only: %i[show]
  resources :wishlist_items, only: %i[create destroy] do
    member { post :move_to_cart }
  end

  get "sitemap.xml", to: "sitemaps#show", defaults: { format: "xml" }, as: :sitemap

  # Endpoint que o gateway configurado chama. O path neutro é o que vai no
  # painel do provedor; o path do fake existe porque os botões de simulação
  # na tela de pagamento apontam para ele.
  post "webhooks/payments", to: "payment_webhooks#create", as: :payment_webhook
  post "webhooks/fake_gateway", to: "payment_webhooks#create", as: :fake_gateway_webhook

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "ready" => "readiness#show", as: :readiness

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # A home é só a apresentação da loja; o catálogo vive em /produtos.
  root "home#show"
end
