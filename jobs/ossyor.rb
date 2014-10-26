require 'net/http'
require 'xmlsimple'
require 'date'
require 'envied'
ENVied.require

def collect_catalog_items(namespaces, file_pattern)
  collect_data(namespaces, file_pattern, 'catalog-item')
end

def collect_rooms(namespaces, file_pattern)
  collect_data(namespaces, file_pattern, 'room')
end

def collect_data(namespaces, file_pattern, root)
  namespaces.map do |namespace|
    begin
      http = Net::HTTP.new(ENVied.HLD_STORAGE)
      response = http.request(Net::HTTP::Get.new(format(file_pattern, namespace)))
      XmlSimple.xml_in(response.body, { 'ForceArray' => false })[root]
    rescue
      nil
    end
  end
end

luminaires = []
rooms = []

SCHEDULER.every '30m', first_in: 0 do |job|
  namespaces = ENVied.HLD_NAMESPACES

  luminaires = collect_catalog_items(namespaces, '/backend/catalog-items-%s.xml')
  luminaires += collect_catalog_items(namespaces, '/backend/ROOMS-%s-global-00090000.xml')
  luminaires = luminaires.compact

  luminaire_counts = luminaires.map do |list|
    list.count
  end.uniq.sort.reverse

  current_count = luminaire_counts[0]
  previous_count = luminaire_counts[1] || current_count
  last_released = current_count - previous_count

  send_event('luminaire_count', {
    current: current_count,
    lastReleased: last_released.abs,
    arrow: last_released > 0 ? 'icon-arrow-up' : 'icon-arrow-down'
  })

  rooms = collect_rooms(namespaces, '/backend/rooms-%s.xml')
  rooms = rooms.compact

  room_counts = rooms.map do |list|
    list.count
  end.uniq.sort.reverse

  current_count = room_counts[0]
  previous_count = room_counts[1] || current_count
  last_released = current_count - previous_count

  send_event('room_count', {
    current: current_count,
    lastReleased: last_released.abs,
    arrow: last_released > 0 ? 'icon-arrow-up' : 'icon-arrow-down'
  })
end


SCHEDULER.every '30s', first_in: 0 do |job|
  namespaces = ENVied.HLD_NAMESPACES

  luminaire_set = luminaires.first
  luminaire = luminaire_set[rand luminaire_set.size]
  ctn = luminaire['asset-id']
  room_type = [luminaire['designed-for']['room-type']].flatten.map { |e| e['name'] }.sample

  room_set = rooms.first
  picked_room = room_set.select { |r| r['type'] == room_type }.sample['id']
  room_id = ("0" + picked_room)[-2..-1]
  zoom = ['04', '08'].sample
  day = ['0201', '0102'].sample

  send_event('background', { image: "http://images.philips.com/is/image/PhilipsConsumer/#{ctn}-#{namespaces.first}-global-#{room_id}#{zoom}#{day}" })
end
