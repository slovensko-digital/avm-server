Rails.application.routes.draw do
  get "/400", to: "errors#bad_request"
  get "/500", to: "errors#internal_error"

  namespace :api do
    namespace :v1 do
      resources :documents, only: [:show, :create, :destroy] do
        member do
          get 'visualization'
          post 'datatosign'
          post 'sign'
          get 'parameters'
          post 'validate'
        end
      end

      resources :devices, only: [:create]
      resources :integrations, only: [:create]
      resources :device_integrations, path: '/device-integrations', only: [:index, :create, :destroy]
      resources :integration_devices, path: '/integration-devices', only: [:index, :destroy]
      resource :sign_request, path: '/sign-request', only: [:create]

      get '/qr-code', to: redirect('https://sluzby.slovensko.digital/autogram-v-mobile/#download', status: 302)
    end
  end

  get '/.well-known/apple-app-site-association' => 'apple#apple_app_site_association'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root to: redirect(ENV.fetch("ROOT_URL_REDIRECT", "/api/v1/"), status: 302)
end
