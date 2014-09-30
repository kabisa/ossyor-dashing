require 'tracker_api'
require 'envied'
ENVied.require

client = TrackerApi::Client.new(token: ENVied.PIVOTAL_TRACKER_API_KEY)
project  = client.project(ENVied.PIVOTAL_TRACKER_PROJECT)

def to_story_json(story, project)
  #tasks = story.tasks
  tasks = project.story(story.id).tasks
  completed = tasks.select { |t| t.complete }
  if tasks.length > 0
    progress = ((completed.length.to_f / tasks.length) * 100).round
  else
    progress = '??'
  end

  {
    title: story.name,
    kind: story.story_type,
    owners: story.owners.map { |owner| owner.initials },
    #tasks: tasks.length,
    #completed: completed.length,
    progress: progress
  }
end

SCHEDULER.every '30m', first_in: 0 do
  story_fields = 'name,story_type,owners'

  rejected = project.stories(
    with_state: 'rejected',
    fields: story_fields
  )
  upcoming = project.stories(
    with_state: 'unstarted',
    fields: story_fields + ',labels',
    limit: 10
  )
  upcoming_json = (rejected + upcoming).select do |story|
    story.labels.select { |label| label.name == 'impeded' }.empty?
  end[0...3].map { |story| to_story_json story, project }

  work_in_progress = project.stories(
    with_state: 'started',
    fields: story_fields
  )
  work_in_progress_json = work_in_progress.map { |story| to_story_json story, project }

  demo = project.stories(
    with_state: 'finished',
    fields: story_fields
  ) + project.stories(
    with_state: 'delivered',
    fields: story_fields
  )
  demo_json = demo.map { |story| to_story_json story, project }

  done = project.stories(
    with_state: 'accepted',
    fields: story_fields,
    accepted_after: (DateTime.now - 7).iso8601
  ).reverse
  done_json = done.map { |story| to_story_json story, project }

  impeded = project.stories(
    with_label: 'impeded',
    fields: story_fields,
  )
  impeded_json = impeded.map { |story| to_story_json story, project }

  send_event('pivotal_upcoming', { stories: upcoming_json })
  send_event('pivotal_wip', { stories: work_in_progress_json })
  send_event('pivotal_demo', { stories: demo_json })
  send_event('pivotal_done', { stories: done_json })
  send_event('pivotal_impeded', { stories: impeded_json })
end

