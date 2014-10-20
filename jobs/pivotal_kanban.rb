require 'tracker_api'
require 'envied'
ENVied.require

client = TrackerApi::Client.new(token: ENVied.PIVOTAL_TRACKER_API_KEY)
project  = client.project(ENVied.PIVOTAL_TRACKER_PROJECT)

ICON_MAPPING = {
  'started' => 'wrench',
  'accepted' => 'ok',
  'rejected' => 'thumbs-down-alt',
  'finished' => 'play',
  'delivered' => 'legal',
  'impeded' => 'exclamation-sign'
}

def to_story_json(story, project)
  tasks = story.tasks
  #tasks = project.story(story.id).tasks
  completed = tasks.select do |t|
    t.complete || t.description[0..1] == '~~'
  end
  if tasks.length > 0
    progress = ((completed.length.to_f / tasks.length) * 100).round
  else
    progress = nil
  end

  branches = story.description.to_s.scan(/branch:`([^`]+)`/).flatten

  branches = nil if branches.empty?
  is_impeded = story.labels.map(&:name).any? { |l| l == 'impeded' }
  state = is_impeded ? 'impeded' : story.current_state
  {
    id: story.id,
    title: story.name,
    kind: story.story_type,
    state: state,
    icon: ICON_MAPPING[state],
    branches: branches,
    owners: story.owners.map do |owner|
      {
        email: owner.email,
        md5: Digest::MD5.hexdigest(owner.email.downcase),
        name: owner.name,
        initials: owner.initials
      }
    end,
    progress: {
      parts: tasks.length,
      progress: progress
    }
  }
end

def send_if_changed(lists, entry, items)
  current_list = items.map { |s| s[:id] }
  send_if_changed_raw(lists, "pivotal_#{entry}", current_list, :stories)
end

def send_if_changed_raw(lists, entry, current_list, key)
  previous_list = lists[entry] || []
  return if current_list == previous_list
  lists[entry] = current_list
  send_event(entry, { key => current_list })
end

STORY_FIELDS = 'project_id,name,description,story_type,owners,current_state,labels'

lists = {}

SCHEDULER.every '10m', first_in: 0 do

  # Due to a bug in tracker_api, the `limit` option does
  # not work, trying to fetch an upcoming release will fetch around 311 unstarted
  # userstories... which take a long time to process

  #upcoming_release = project.stories(
    #with_state: 'unstarted',
    #limit: 2,
    #fields: STORY_FIELDS
  #)[0..2].select { |story| story.story_type == 'release' }
  upcoming_release = []

  work_in_progress = project.stories(
    with_state: 'started',
    fields: STORY_FIELDS
  )
  work_in_progress_json = work_in_progress.map { |story| to_story_json story, project }
    .sort do |a, b|
    next 1 if a[:progress][:progress] == nil
    next -1 if b[:progress][:progress] == nil
    b[:progress][:progress] <=> a[:progress][:progress]
  end

  demo = upcoming_release + project.stories(
    with_state: 'rejected',
    fields: STORY_FIELDS
  ) + project.stories(
    with_state: 'delivered',
    fields: STORY_FIELDS
  ) + project.stories(
    with_state: 'finished',
    fields: STORY_FIELDS
  )
  demo_json = demo.map { |story| to_story_json story, project }

  done = project.stories(
    with_state: 'accepted',
    fields: STORY_FIELDS,
    accepted_after: (DateTime.now - 7).iso8601
  ).reverse.reject do |s|
    (s.labels.map(&:name) & ['achievements']).any?
  end
  done_json = done.map { |story| to_story_json story, project }

  wip_list = demo_json + work_in_progress_json
  wip_list.each { |story| send_event("pivotal_story_#{story[:id]}", story) }
  done_json.each { |story| send_event("pivotal_story_#{story[:id]}", story) }

  send_if_changed(lists, 'wip', wip_list)
  send_if_changed(lists, 'done', done_json)

  achievement_chore = project.stories(
    with_state: 'accepted',
    with_label: 'achievements',
    accepted_after: (DateTime.now - 15).iso8601
  ).reverse.first
  if achievement_chore
    achievements = []
    goals = []
    achievement_chore.tasks.map do |t|
      if t.complete
        achievements << {
          name: t.description
        }
      else
        goals << {
          title: t.description
        }
      end
    end
    send_if_changed_raw(lists, 'achievements', achievements, :achievements)
    send_if_changed_raw(lists, 'goals', goals, :goals)
  end
end
