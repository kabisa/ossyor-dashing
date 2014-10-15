require 'net/http'
require 'xmlsimple'
require 'date'
require 'envied'
ENVied.require

def collect_counts(namespaces, file_pattern)
  namespaces.map do |namespace|
    begin
      http = Net::HTTP.new(ENVied.HLD_STORAGE)
      response = http.request(Net::HTTP::Get.new(format(file_pattern, namespace)))
      XmlSimple.xml_in(response.body, { 'ForceArray' => false })['catalog-item'].count
    rescue
      nil
    end
  end
end

SCHEDULER.every '30m', :first_in => 0 do |job|

  namespaces = ENVied.HLD_NAMESPACES
  luminaire_counts = collect_counts(namespaces, '/backend/ROOMS-%s-global-000900000000X.xml')
  luminaire_counts += collect_counts(namespaces, '/backend/ROOMS-%s-global-00090000.xml')
  luminaire_counts += collect_counts(namespaces, '/backend/catalog-items-%s.xml')

  luminaire_counts = luminaire_counts.compact.uniq.sort.reverse

  current_count = luminaire_counts[0]
  previous_count = luminaire_counts[1] || current_count
  last_released = current_count - previous_count

  send_event('luminaire_count', {
    current: current_count,
    lastReleased: last_released.abs,
    arrow: last_released > 0 ? 'icon-arrow-up' : 'icon-arrow-down'
  })
end
