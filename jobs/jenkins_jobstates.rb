#require 'net/http'
require 'json'

jenkins_host = 'oss-ci.ddns.htc.nl.philips.com'
jenkins_view = 'ossyor'
jenkins_port = '8080'

SCHEDULER.every '1m', :first_in => 0 do
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
    background.concat ' widget widget-jenkins-jobstates jenkins_jobstates'

    send_event('jenkins_jobstates', { blue: blue, red: red, grey: grey, background: background })
  end
end
