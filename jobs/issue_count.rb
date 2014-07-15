require "net/https"
require "uri"

SCHEDULER.every '30m', :first_in => 0 do |job|
  uri = URI.parse('https://falatados.ehv.campus.philips.com/projects/oss/issues.json')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth(ENV['REDMINE_API_KEY'], '')
  response = http.request(request)

  json_response = JSON.parse response.body
  open_issues = json_response["total_count"]

  send_event('issue_count', { current: open_issues.to_i })
end
