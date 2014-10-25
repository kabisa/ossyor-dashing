def send_if_changed_raw(lists, entry, current_list, key)
  previous_list = lists[entry] || []
  return if current_list == previous_list
  lists[entry] = current_list
  send_event(entry, { key => current_list })
end

def clean_up_history(pattern, time = Time.now)
  Sinatra::Application.settings.history.select do |entry, data|
    entry.match pattern
  end.map do |entry, data|
    { id: entry, updated_at: Time.at(JSON.parse(data[/{.*}/])['updatedAt']) }
  end.select do |data|
    data[:updated_at] < time
  end.each do |to_remove|
    Sinatra::Application.settings.history.delete to_remove[:id]
  end
end

def relay_event(name, data)
  return unless ENVied.RELAY_EVENTS
  HTTParty.post(
    "#{ENVied.RELAY_EVENTS}widgets/#{name}",
    body:  data.merge(auth_token: ENVied.DASHING_AUTH_TOKEN).to_json
  )
end
