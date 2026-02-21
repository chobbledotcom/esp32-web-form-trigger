Rails.application.routes.draw do
  resources :devices, except: [:destroy, :show] do
    member do
      post :archive
      post :unarchive
    end
  end
  resources :forms, except: [:show] do
    member do
      patch :remove_image
    end
  end
  resources :submissions, only: [:index, :show] do
    member do
      post :reset_credit
    end
  end

  # Webhook trigger (e.g. from Jotform quiz pass)
  post "webhooks/trigger/:code/:device_id", to: "webhooks#trigger", as: "webhook_trigger"

  # Public form routes
  get "form/:code/:device_id", to: "public_forms#show", as: "public_form"
  post "form/:code/:device_id", to: "public_forms#create"
  get "form/:code/:device_id/thanks", to: "public_forms#thanks", as: "form_thanks"
  get "form/:code/:device_id/qr_code", to: "public_forms#qr_code", as: "form_qr_code"

  # Public device route
  get "devices/:id", to: "devices#show", as: "public_device"
  post "devices/:id/reset_credit", to: "devices#reset_credit", as: "reset_device_credit"

  # API endpoints
  namespace :api do
    namespace :v1 do
      get "credits/check", to: "credits#check"
      post "credits/claim", to: "credits#claim"
    end
  end

  get "up" => "rails/health#show", :as => :rails_health_check

  get "service-worker" => "rails/pwa#service_worker", :as => :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest

  root "sessions#new"

  get "signup", to: "users#new"
  post "signup", to: "users#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Users management (full CRUD)
  resources :users do
    member do
      get "change_password"
      patch "update_password"
      post "impersonate"
      post "toggle_admin"
    end
  end

  # Inspections
  resources :inspections do
    collection do
      get "search"
      get "overdue"
    end
    member do
      get "certificate"
      get "qr_code"
    end
  end

  # Images admin
  get "images/all", to: "images#all"
  get "images/orphaned", to: "images#orphaned"

  # Links admin
  get "links", to: "links#index"

  # Codes management
  resources :codes, except: [:edit, :update, :show]

  # Public code routes
  get "code/:id", to: "public_codes#show", as: "public_code"
  post "code/:id", to: "public_codes#create"
  get "code/:id/thanks", to: "public_codes#thanks", as: "code_thanks"

  # Email queue monitoring
  resources :email_queues, only: [:index] do
    member do
      post :retry
    end
  end

  # Short URL for certificates
  get "c/:id", to: "inspections#certificate", as: "short_certificate"
  get "C/:id", to: "inspections#certificate", as: "short_certificate_uppercase"
end
