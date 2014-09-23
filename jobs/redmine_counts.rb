require "net/https"
require "uri"
require 'envied'
ENVied.require

def get_redmine_issue_count(tracker_id, priority = nil)
  url = "https://falatados.ehv.campus.philips.com/projects/oss/issues.json?tracker_id=#{tracker_id}&limit=1"
  url += "&status_id=!5"
  if priority
    url += "&priority_id=#{priority}"
  end
  uri = URI.parse(URI::encode(url))
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth(ENVied.REDMINE_API_KEY, '')
  response = http.request(request)

  json_response = JSON.parse response.body
  json_response["total_count"].to_i
end

SCHEDULER.every '30m', :first_in => 0 do |job|
  {
    'bugs' => 1,
    'support' => 3
  }.each do |tracker, tracker_id|
    high = get_redmine_issue_count(tracker_id, '3|4|5')
    send_event("redmine_#{tracker}", {
      high: high,
      total: get_redmine_issue_count(tracker_id)
    })
  end
end
