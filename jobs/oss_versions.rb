require 'net/http'
require 'nokogiri'
require 'date'
require 'envied'
ENVied.require

SCHEDULER.every '10m', :first_in => 0 do |job|

  environments = ENVied.HLD_SERVERS
  versions = []
  main_version = 'Environments'

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
        if index == 0
          main_version = version
        end

        versions << { name: environment, version: version, content: content }
      end
      if version_tag.empty?
        versions << { name: environment, version: 'ERROR', content: 'ERROR' }
      end
    rescue StandardError => e
      versions << { name: environment, version: e.message, content: 'ERROR' }
    end
  end

  send_event('environment_versions', {
    environments: versions, main_title: main_version
  })
end

