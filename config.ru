require 'sinatra/cyclist'
require 'dashing'
require 'envied'
ENVied.require

configure do
  set :auth_token, ENVied.DASHING_AUTH_TOKEN
  set :default_dashboard, 'ossyor'

  helpers do
    def protected!
     # Put any authentication code you want in here.
     # This method is run before accessing any resource.
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

set :routes_to_cycle_through, [:ossyor, :kanban]

run Sinatra::Application
