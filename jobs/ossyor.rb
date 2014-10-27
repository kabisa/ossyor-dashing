require 'net/http'
require 'xmlsimple'
require 'date'
require 'envied'
require 'nokogiri'

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
online_versions = []

SCHEDULER.every '10m', :first_in => 0 do |job|

  environments = ENVied.HLD_SERVERS
  main_version = 'Environments'
  versions = []

  environments.each.with_index do |environment, index|
    begin
      http = Net::HTTP.new("www.#{environment}.philips.com")
      response = http.request(Net::HTTP::Get.new('/'))
      doc = Nokogiri::HTML(response.body)
      version_tag = doc.css('meta[name="PHILIPS.PWL.VERSION"]')
      version_tag.each do |meta_tag|
        version = meta_tag['content']
        if version =~ /branch:/
          version = version.match(/branch:\s+(?<version>.*)$/)[:version]
        end
        content = 'unknown'
        doc.css('meta[name="PHILIPS.PWL.CONTENT-NAMESPACE"]').each do |namespace_meta_tag|
          content = namespace_meta_tag['content']
        end
        main_version = version if index == 0

        versions << { name: environment, version: version, content: content }
      end
      versions << { name: environment, version: 'ERROR', content: 'ERROR' } if version_tag.empty?
    rescue StandardError => e
      versions << { name: environment, version: e.message, content: 'ERROR' }
    end
  end
  online_versions = versions

  send_event('environment_versions', {
    environments: versions, main_title: main_version
  })
end


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
  next unless luminaire_set
  luminaire_set = luminaire_set.reject { |l| l['designed-for'].empty? }
  luminaire = luminaire_set[rand luminaire_set.size]
  ctn = luminaire['asset-id']
  room_type = [luminaire['designed-for']['room-type']].flatten.map { |e| e['name'] }.sample

  room_set = rooms.first
  picked_room = room_set.select { |r| r['type'] == room_type }.sample['id']
  room_id = ("0" + picked_room)[-2..-1]
  #zoom = ['04', '08'].sample
  zoom = '08'
  day = ['0201', '0102'].sample

  send_event('background', {
    image: "http://images.philips.com/is/image/PhilipsConsumer/#{ctn}-#{namespaces.first}-global-#{room_id}#{zoom}#{day}"
  })
end

SCHEDULER.every '45m', first_in: '2m' do |job|
  next unless online_versions.any?

  facts = []
  facts.push(
    prefix: 'version ',
    value: online_versions.first[:version],
    suffix: ' online'
  )

  production_namespace = online_versions.first[:content]
  $stdout.puts 'Production Version', online_versions.first.inspect

  luminaires = collect_catalog_items([production_namespace], '/backend/catalog-items-%s.xml')
  facts.push(
    value: luminaires.first.size,
    suffix: ' luminaires'
  )

  rooms = collect_rooms([production_namespace], '/backend/rooms-%s.xml')
  facts.push(
    value: rooms.first.size,
    suffix: ' rooms'
  )

  send_event('facts', facts: facts)
end
