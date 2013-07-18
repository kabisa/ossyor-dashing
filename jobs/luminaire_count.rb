require 'net/http'
require 'xmlsimple'
require 'date'

SCHEDULER.every '30m', :first_in => 0 do |job|
  # http://assets.pwl.philips.com.s3.amazonaws.com/backend/ROOMS-HL2-global-000900000000X.xml

  namespaces = %w(HL1 HL2 HL3)
  luminaire_counts = namespaces.map do |namespace|
    http = Net::HTTP.new('assets.pwl.philips.com.s3.amazonaws.com')
    response = http.request(Net::HTTP::Get.new("/backend/ROOMS-#{namespace}-global-000900000000X.xml"))
    luminaire_count = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['catalog-item'].count
  end.uniq.sort.reverse

  planned_count = ((((Date.today.year - 2013) * 12) + (Date.today.month - 1)) * 200) + 50

  current_count = luminaire_counts[0]
  previous_count = luminaire_counts[1]
  last_released = current_count - previous_count

  send_event('luminaire_count', {
    current: current_count,
    targetCount: planned_count,
    difference:  current_count - planned_count,
    lastReleased: last_released.abs,
    arrow: last_released > 0 ? 'icon-arrow-up' : 'icon-arrow-down'
  })
end
