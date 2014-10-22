require 'net/http'
require 'json'
require 'envied'
ENVied.require

jenkins_reachable = false
fake_jenkins = true
begin
  http = Net::HTTP.new(ENVied.JENKINS_HOST, ENVied.JENKINS_PORT)
  url  = format('/view/%s/api/json?tree=jobs[name,color]', ENVied.JENKINS_VIEW)
  http.request(Net::HTTP::Get.new(url))
  jenkins_reachable = true
  fake_jenkins = false
rescue
  puts 'Jenkins not reachable, skipping updates'
end

def clean_up_history(pattern, time = Time.now)
  Sinatra::Application.settings.history.select do |entry, data|
    entry.match pattern
  end.map do |entry, data|
    { id: entry, updated_at: Time.at(JSON.parse(data[/{.*}/])['updatedAt']) }
  end.select do |data|
    data[:updated_at] < time
  end.each do |to_remove|
    Sinatra::Application.settings.history.delete to_remove[:id]
  end
end

def send_job_list(name, list)
  overal_state = 'success'
  overal_state = 'failed' if list.any? { |j| j['state'] != 'success' }
  send_event("jenkins_#{name}", jobs: list.map { |j| j['name'] }, state: overal_state)
end

def fetch_jenkins_jobs
  http = Net::HTTP.new(ENVied.JENKINS_HOST, ENVied.JENKINS_PORT)
  url  = format('/view/%s/api/json?tree=jobs[name,color]', ENVied.JENKINS_VIEW)
  response = http.request(Net::HTTP::Get.new(url))
  JSON.parse(response.body)['jobs']
end

def fake_jenkins_jobs
  [{
    'color' => 'blue',
    'name' => 'ossyor_develop'
  }, {
    'color' => 'blue_anime',
    'name' => 'ossyor_epic-hotspots'
  }, {
    'color' => 'red_anime',
    'name' => 'ossyor_experiment-chardin'
  }, {
    'color' => 'grey',
    'name' => 'ossyor_feature-my-story-branch'
  }]
end

def fetch_queue_items
  url = '/queue/api/json?tree=items[inQueueSince,task[name]]'
  response = http.request(Net::HTTP::Get.new(url))
  JSON.parse(response.body)['items']
end

def fake_queue_items
  [{
    'inQueueSince' => Time.new,
    'task' => {
      'name' => 'ossyor_develop'
    }
  }]
end

SCHEDULER.every '30s', :first_in => 0 do

  jobs = fake_jenkins ? fake_jenkins_jobs : fetch_jenkins_jobs
  queue_items = fake_jenkins ? fake_queue_items : fetch_queue_items

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

    clean_up_history(/^jenkins_job_.*/, Time.now - 60) # also cleans up build messages
  end
end if jenkins_reachable || fake_jenkins

