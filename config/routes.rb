Rails.application.routes.draw do
  resources :notifications
  resources :conversations
  resources :possible_answers
  resources :responses
  resources :questions
  resources :sent_messages
  mount Facebook::Messenger::Server, at: 'bot'
  resources :broadcasts
  resources :messages
  resources :contents
  resources :articles
  resources :brands
  resources :shows
  get 'data', to: 'welcome#data'
  root to: 'welcome#index'
  
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
