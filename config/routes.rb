Rails.application.routes.draw do
  root 'welcome#index'

  post 'users/bulk', to: 'users#bulk_upload', as: 'users_bulk_upload'
  resources :users, only: [:index]
end
