require 'sinatra/cyclist'
require 'dashing'
require 'envied'
ENVied.require

configure do
  set :auth_token, ENVied.DASHING_AUTH_TOKEN
  set :default_dashboard, 'ossyor'

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['oss', 'dashing']
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

set :routes_to_cycle_through, [:ossyor, :kanban]

run Sinatra::Application
