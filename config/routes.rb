Rails.application.routes.draw do
  mount Facebook::Messenger::Server, at: 'bot'

  resources :articles do
    collection do
      get 'top_stories'
    end
  end
  resources :brands
  resources :broadcasts
  resources :contents
  resources :conversations
  resources :messages
  resources :notifications
  resources :possible_answers
  resources :questions
  resources :responses
  resources :sent_messages
  resources :shows
  resources :users

  get 'data', to: 'welcome#data'

  root to: 'welcome#index'
  
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
