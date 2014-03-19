require 'net/http'
require 'nokogiri'
require 'date'

SCHEDULER.every '10m', :first_in => 0 do |job|
  # http://www.pwl.philips.com/

  environments = %w(pwl content.pwl staging.pwl demo.pwl)
  versions = []

  environments.each do |environment|
    http = Net::HTTP.new("www.#{environment}.philips.com")
    response = http.request(Net::HTTP::Get.new('/'))
    doc = Nokogiri::HTML(response.body)
    doc.css('meta[name="PHILIPS.PWL.VERSION"]').each do |meta_tag|
      version = meta_tag['content']
      if version =~ /branch:/
        version = version.match(/branch:\s+(?<version>.*)$/)[:version]
      end
      content = 'unknown'
      doc.css('meta[name="PHILIPS.PWL.CONTENT-NAMESPACE"]').each do |namespace_meta_tag|
        content = namespace_meta_tag['content']
      end

      versions << { name: environment, version: version, content: content }
    end
  end

  send_event('environment_versions', {
    environments: versions
  })

end

