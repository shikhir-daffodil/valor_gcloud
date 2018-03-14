Rails.application.routes.draw do
  get 'index/index'
  get 'index/get_token'
  get 'index/get_instance_status'
  get 'index/stop_instance_action'
  get 'index/delete_instance_action'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
