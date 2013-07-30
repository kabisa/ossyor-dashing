require 'pingdom-client'

api_key = ENV['PINGDOM_API_KEY'] || ''
user = ENV['PINGDOM_USER'] || ''
password = ENV['PINGDOM_PASSWORD'] || ''

SCHEDULER.every '1m', :first_in => 0 do
  client = Pingdom::Client.new :username => user, :password => password, :key => api_key

  if client.checks
    checks = client.checks.map { |check|
      if check.status == 'up'
        color = 'green'
      else
        color = 'red'
      end

      { name: check.name, state: color }
    }

    checks.sort_by { |check| check['name'] }

    send_event('pingdom', { checks: checks })
  end
end

