require 'net/http'
require 'json'
require 'envied'
ENVied.require

jenkins_reachable = false
begin
  http = Net::HTTP.new(ENVied.JENKINS_HOST, ENVied.JENKINS_PORT)
  url  = format('/view/%s/api/json?tree=jobs[name,color]', ENVied.JENKINS_VIEW)
  http.request(Net::HTTP::Get.new(url))
  jenkins_reachable = true
rescue
  puts 'Jenkins not reachable, skipping updates'
end

def send_job_list(name, list)
  overal_state = 'success'
  overal_state = 'failed' if list.any? { |j| j['state'] != 'success' }
  send_event("jenkins_#{name}", jobs: list.map { |j| j['name'] }, state: overal_state)
end

SCHEDULER.every '30s', :first_in => 0 do
  http = Net::HTTP.new(ENVied.JENKINS_HOST, ENVied.JENKINS_PORT)
  url  = format('/view/%s/api/json?tree=jobs[name,color]', ENVied.JENKINS_VIEW)
  response = http.request(Net::HTTP::Get.new(url))
  jobs     = JSON.parse(response.body)['jobs']

  #jobs = [{
    #'color' => 'blue',
    #'name' => 'ossyor_develop'
  #}, {
    #'color' => 'blue_anime',
    #'name' => 'ossyor_epic-hotspots'
  #}, {
    #'color' => 'red_anime',
    #'name' => 'ossyor_experiment-chardin'
  #}, {
    #'color' => 'grey',
    #'name' => 'ossyor_feature-my-story-branch'
  #}]

  url = '/queue/api/json?tree=items[inQueueSince,task[name]]'
  response = http.request(Net::HTTP::Get.new(url))
  queue_items = JSON.parse(response.body)['items']

  #queue_items = [{
    #'inQueueSince' => Time.new,
    #'task' => {
      #'name' => 'ossyor_develop'
    #}
  #}]

  queue = {}

  if queue_items
    queue_items.sort_by { |item| item['inQueueSince'] }
    queue_items.reverse!
    queue_items = queue_items[0..7]
    position = 1
    queue_items.map do |item|
      name = item['task']['name']
      queue[name] ||= []
      queue[name] << position
      position += 1
    end
  end

  if jobs
    jobs.map! do |job|

      state = case job['color']
      when 'blue', 'blue_anime' then 'success'
      when 'red', 'red_anime' then 'failed'
      when 'aborted', 'aborted_anime' then 'aborted'
      else 'unknown'
      end
      building = job['color'][-6..-1] == '_anime'
      name = job['name'][7..-1]

      stable = false
      stable = true if name[0..7] == 'release-'
      stable = true if name == 'develop'
      stable = true if name[0..4] == 'epic-'

      {
        'name' => name,
        'state' => state,
        'stable' => stable,
        'queuePositions' => queue[job['name']],
        'building' => building
      }
    end
    jobs.sort_by { |job| job['name'] }

    # send all build stati as seperate events
    jobs.each do |job|
      send_event("jenkins_job_#{job['name']}", job)
    end

    # send list of 'stable' branches
    send_job_list('stable', jobs.select { |j| j['stable'] })
    send_job_list('unstable', jobs.reject { |j| j['stable'] })
    send_job_list('jobs', jobs)
  end
end if jenkins_reachable

