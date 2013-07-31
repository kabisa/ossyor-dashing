#require 'net/http'
require 'json'

jenkins_host = 'oss-ci.ddns.htc.nl.philips.com'
jenkins_view = 'ossyor'
jenkins_port = '8080'

jenkins_reachable = false
begin
  http = Net::HTTP.new(jenkins_host,jenkins_port)
  url  = '/view/%s/api/json?tree=jobs[color]' % jenkins_view
  response = http.request(Net::HTTP::Get.new(url))
  jenkins_reachable = true
rescue
  puts 'Jenkins not reachable, skipping updates'
end

SCHEDULER.every '30s', :first_in => 0 do
  http = Net::HTTP.new(jenkins_host,jenkins_port)
  url  = '/view/%s/api/json?tree=jobs[color]' % jenkins_view

  response = http.request(Net::HTTP::Get.new(url))
  jobs     = JSON.parse(response.body)['jobs']

  if jobs
    blue = 0
    red = 0
    grey = 0

    jobs.each { |job|
      case job['color']
      when 'blue', 'blue_anime'
        blue += 1
      when 'red', 'red_anime'
        red += 1
      else
        grey += 1
      end
    }
    background = 'success'
    background = 'unknown' if grey > 0
    background = 'fail' if red > 0
    background.concat ' icon-background'

    send_event('jenkins_jobstates', { blue: blue, red: red, grey: grey, background: background })
  end
end if jenkins_reachable
