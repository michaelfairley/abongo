Rails3::Application.routes.draw do
  match ':action(/:id(.:format))' => 'application#index'
end
