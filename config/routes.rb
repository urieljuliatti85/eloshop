Rails.application.routes.draw do
  # A documentação da API é do admin logado e de quem tem um ApiClient ativo
  # (ver ApiDocsAuthentication); a API v1 exige o mesmo token.
  mount ApiDocsAuthentication.new(Rswag::Ui::Engine) => "/api-docs"
  mount ApiDocsAuthentication.new(Rswag::Api::Engine) => "/api-docs"
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root to: "dashboard#index"
    get "analytics", to: "analytics#index", as: :analytics
    get "observability", to: "observability#index", as: :observability
    get "financials", to: "financials#index", as: :financials
    get "financials/export", to: "financials#export", as: :financials_export
    post "financials/reconciliation", to: "financials#refresh_reconciliation", as: :financials_reconciliation
    post "vendas/abrir", to: "sales_openings#create", as: :sales_opening

    resources :fraud_alerts, only: %i[index], path: "fraudes" do
      member { patch :resolve }
    end

    get "auditoria", to: "audit_logs#index", as: :audit_logs

    resources :sellers, only: %i[index show] do
      member do
        patch :approve
        patch :suspend
        patch :hide
        patch :unhide
        patch :showcase
        patch :unshowcase
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
      collection do
        patch :bulk_discontinue
        patch :bulk_unpublish
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

    resources :seller_reports, only: %i[index] do
      member do
        patch :review
        patch :resolve
        patch :dismiss
      end
    end

    resources :categories, except: %i[show]
    resources :category_suggestions, path: "categorias-sugeridas", only: :index do
      member do
        patch :accept
        patch :reject
      end
    end

    resources :coupons, except: %i[show]

    resources :api_clients, path: "clientes-de-api", only: %i[index new create] do
      member { patch :revoke }
    end

    resources :mercado_pago_test_accounts, path: "contas-de-teste-mercado-pago", except: %i[show]

    resources :orders, only: %i[index show] do
      member do
        post :refund
        post :manual_refund
        post :cancel
      end
    end

    # Solicitações pós-venda (ADR 008): fila com prazo, atendimento e status.
    resources :return_requests, only: %i[index show update], path: "solicitacoes"

    resources :notifications, only: %i[index] do
      member { patch :mark_as_read }
    end
  end

  resources :products, only: :index, path: "produtos" do
    # Autocomplete da busca da vitrine. Declarada antes de `produtos/:slug`
    # (legacy_show) para "sugestoes" não ser lido como slug de produto.
    get :sugestoes, action: :suggestions, on: :collection, as: :suggestions
  end
  # A vitrine pública do ateliê ocupa o mesmo prefixo que já identificava o
  # vendedor na URL do produto.
  resources :sellers, only: %i[index show], param: :slug, path: "artesaos" do
    resources :seller_reports, only: :create, path: "denuncias"
  end
  scope "artesaos/:seller_slug" do
    resources :products, only: :show, param: :slug, path: "produtos" do
      resources :reviews, only: :create
    end
  end
  get "produtos/:slug", to: "products#legacy_show", as: :legacy_product

  get "seja-um-artesao", to: "seller_registrations#new", as: :new_seller_registration
  get "seja-um-artesao/nome", to: "seller_registrations#name_availability", as: :seller_registration_name_availability
  post "seja-um-artesao", to: "seller_registrations#create", as: :seller_registration

  # Distribuidor de insumos (ADR 007, Fase 25): cadastro, porta de login e
  # painel próprios sob /atacado. O cadastro fica atrás de
  # `config.x.distributors.signup_enabled`; login e painel, não, para quem já
  # existe continuar entrando. A conexão do Mercado Pago passa pelas rotas de
  # /painel, porque o redirect URI registrado no provedor é um só.
  # Lista pública dos distribuidores de insumos (ADR 007). A loja de cada um
  # (/distribuidores/:slug) e a vitrine /insumos chegam no PR C da Fase 26.
  get "distribuidores", to: "distributors#index", as: :distributors
  # Vitrine de insumos (Fase 26, PR C): a lista geral, a loja de cada
  # distribuidor e a página do insumo, no formato do ateliê e fora de
  # /artesaos e /produtos (ADR 007, endereços de 2026-11-07).
  get "insumos", to: "supplies#index", as: :supplies
  get "distribuidores/:slug", to: "distributors#show", as: :distributor_store
  get "distribuidores/:seller_slug/insumos/:slug", to: "supplies#show", as: :supply
  get "atacado/cadastro", to: "distributor_registrations#new", as: :new_distributor_registration
  post "atacado/cadastro", to: "distributor_registrations#create", as: :distributor_registration
  get "atacado/termos-comerciais", to: "seller_portal/terms#show", as: :distributor_terms, defaults: { kind: "distributor" }
  post "atacado/termos-comerciais", to: "seller_portal/terms#accept"
  scope module: :distributor_portal, as: :distributor, path: "atacado" do
    get "entrar", to: "sessions#new", as: :login
    post "entrar", to: "sessions#create"
    delete "sair", to: "sessions#destroy", as: :logout
    get "painel", to: "dashboard#index", as: :root

    # Telas que o painel do ateliê já tem, reaproveitadas por subclasse em
    # DistributorPortal (revisão de arquitetura de 2026-11-07, opção B). Os
    # nomes espelham os de /painel, para `panel_path` achar a tela de cada
    # tipo; "Dados da distribuidora" é `profile` (o `atelier` do ateliê).
    scope "painel" do
      get "primeiros-passos(/:etapa)", to: "getting_started#show", as: :getting_started,
        constraints: { etapa: /endereco|mercado-pago|chave-pix|primeira-peca|aprovacao/ }
      resource :origin_address, only: :update, controller: "origin_addresses", path: "primeiros-passos/endereco"
      resource :pix_key_confirmation, only: %i[create destroy], path: "chave-pix"
      get "cadastro-chave-pix", to: "pix_key_guides#show", as: :pix_key_guide
      get "conta-vendedor-mercado-pago", to: "mercado_pago_guides#show", as: :mercado_pago_guide
      resource :profile, only: %i[show edit update], controller: "profiles", path: "dados"
      get "dados/cep/:cep", to: "postal_codes#show", as: :profile_postal_code, constraints: { cep: /\d{5}-?\d{3}/ }
      get "dados/enderecos", to: "postal_codes#index", as: :profile_postal_codes
      resources :notifications, only: %i[index], path: "avisos" do
        member { patch :mark_as_read }
      end

      # Catálogo de insumos (Fase 26, PR B): mesmas ações do catálogo do
      # ateliê, sem variantes, personalização e ações em lote, que entram
      # quando os distribuidores pedirem.
      resources :products, path: "insumos", except: :destroy, path_names: { new: "novo", edit: "editar" } do
        member do
          patch :publish
          patch :unpublish
          patch :discontinue
        end
        resources :product_images, path: "imagens", only: %i[destroy]
      end
    end
  end

  scope module: :seller_portal, as: :seller, path: "painel" do
    get "entrar", to: "sessions#new", as: :login
    post "entrar", to: "sessions#create"
    delete "sair", to: "sessions#destroy", as: :logout

    root to: "dashboard#index"
    # Uma etapa por tela; sem etapa na URL, abre a próxima pendente.
    get "primeiros-passos(/:etapa)", to: "getting_started#show", as: :getting_started,
      constraints: { etapa: /endereco|mercado-pago|chave-pix|superfrete|primeira-peca|aprovacao/ }
    # Endereço de origem preenchido dentro dos Primeiros passos do painel inicial.
    resource :origin_address, only: :update, controller: "origin_addresses", path: "primeiros-passos/endereco"
    post "tour/concluir", to: "tours#complete", as: :tour_completion
    resource :pix_key_confirmation, only: %i[create destroy], path: "chave-pix"
    get "cadastro-chave-pix", to: "pix_key_guides#show", as: :pix_key_guide
    get "conta-vendedor-mercado-pago", to: "mercado_pago_guides#show", as: :mercado_pago_guide
    get "termos-comerciais", to: "terms#show", as: :terms
    post "termos-comerciais", to: "terms#accept"
    # Dados do próprio ateliê. Sempre a partir de `current_seller`, nunca de
    # um id na URL — é a regra do painel inteiro.
    resource :atelier, only: %i[show edit update], controller: "ateliers", path: "atelie"

    # Tema da vitrine pública (logo, capa, rodapé, paleta, fonte e layout).
    resource :theme, only: %i[edit update], controller: "themes", path: "atelie/tema" do
      # A vitrine real com o rascunho aplicado, para o iframe do editor.
      get :preview
    end

    get "atelie/cep/:cep", to: "postal_codes#show", as: :atelier_postal_code, constraints: { cep: /\d{5}-?\d{3}/ }
    get "atelie/enderecos", to: "postal_codes#index", as: :atelier_postal_codes

    get "mercado-pago/conectar", to: "mercado_pago_connections#create", as: :mercado_pago_connect
    get "mercado-pago/callback", to: "mercado_pago_connections#callback", as: :mercado_pago_callback
    delete "mercado-pago", to: "mercado_pago_connections#destroy", as: :mercado_pago_connection

    get "superfrete/conectar", to: "superfrete_connections#create", as: :superfrete_connect
    get "superfrete/callback", to: "superfrete_connections#callback", as: :superfrete_callback
    delete "superfrete", to: "superfrete_connections#destroy", as: :superfrete_connection
    patch "frete/preferencia", to: "shipping_preferences#update", as: :shipping_preference
    # Frete e entregas: o passo a passo da SuperFrete, a conexão e a escolha do frete.
    get "frete", to: "shipping_settings#show", as: :shipping_settings

    resources :category_suggestions, path: "categorias/sugestoes", only: :create

    resources :products, except: :destroy do
      member do
        patch :publish
        patch :unpublish
        patch :discontinue
      end
      collection do
        patch :bulk_discontinue
        patch :bulk_unpublish
      end

      resources :product_variants, path: "variantes", except: %i[index show]
      resources :personalization_options, path: "personalizacoes", except: %i[index show]
      resources :product_images, path: "imagens", only: %i[destroy]
    end
    resources :orders, only: %i[index show] do
      member do
        post :cancel
        patch :start_production
        patch :ship
        patch :deliver
      end
      resource :shipping_label, path: "etiqueta", path_names: { new: "nova" }, only: %i[new create destroy] do
        get :print, path: "imprimir"
        post :reconcile, path: "conferir"
      end
    end
    get "mensagens", to: "order_messages#index", as: :messages
    get "orders/:order_id/messages", to: "order_messages#show", as: :order_messages
    post "orders/:order_id/messages", to: "order_messages#create"

    resources :notifications, only: %i[index] do
      member { patch :mark_as_read }
    end

    resources :reviews, only: %i[index] do
      member { patch :reply }
    end
  end

  # `format: :json` fixo: a API v1 só tem views `.jbuilder`, então não há um
  # segundo formato para negociar — sem isso, um `Accept: text/html` (o que o
  # navegador manda ao colar a URL na barra) não acha view e cai numa página
  # de exceção HTML do Rails, em vez do JSON que o endpoint sempre serve.
  # Clientes de API (curl, fetch, SDKs, que mandam */* ou nada) já
  # funcionavam; quem pagava o preço era quem estava conhecendo a API.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :products, only: :index
      resources :sellers, only: %i[index show], param: :slug
      resources :categories, only: :index
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

  get "como-funciona", to: "how_it_works#show", as: :how_it_works

  get "politica-de-privacidade", to: "privacy_policy#show", as: :privacy_policy

  get "customers/disponibilidade-email", to: "customers#email_availability", as: :customer_email_availability
  resources :customers, only: %i[new create]
  resource :customer_session, only: %i[new create destroy]
  # Recuperação de senha do comprador (admin e vendedor usam /passwords).
  resources :customer_passwords, only: %i[new create edit update], param: :token, path: "recuperar-senha"

  # Área do cliente: os destinos da conta sob um prefixo só, para o menu do
  # topo e o painel terem para onde apontar.
  scope "minha-conta", as: :account do
    root to: "accounts#show", as: :root
    resource :profile, only: %i[edit update], controller: "account_profiles", path: "cadastro"
  end

  # `new`/`create` já eram usados dentro do checkout; a área do cliente
  # acrescenta a gestão (listar, editar, excluir).
  get "addresses/postal-code/:cep", to: "postal_codes#show", as: :address_postal_code,
    constraints: { cep: /\d{5}-?\d{3}/ }
  get "addresses/postal-codes", to: "postal_codes#index", as: :address_postal_codes
  resources :addresses, only: %i[index new create edit update destroy]
  resources :orders, only: %i[index new create show] do
    member do
      post :cancel
      patch :deliver
    end
    resources :messages, only: %i[index create], controller: "order_messages"
    # Desistência ou problema pelo site, com protocolo (ADR 008, Decreto 7.962).
    resources :return_requests, only: %i[new create show], path: "solicitacoes"
    resource :payment, only: %i[new create] do
      get :status
    end
  end

  resources :notifications, only: %i[index] do
    member { patch :mark_as_read }
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
