require 'tracker_api'

client = TrackerApi::Client.new(token: ENV['PIVOTAL_TRACKER_API_KEY'])                    # Create API client
project  = client.project(ENV['PIVOTAL_TRACKER_PROJECT'])                                         # Find project with given ID

def to_story_json(story)
  {
    title: story.name,
    kind: story.story_type,
    owners: story.owners.map { |owner| owner.initials }
  }
end

SCHEDULER.every '3m', first_in: 0 do
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
  end.map { |story| to_story_json story }[0...3]

  work_in_progress = project.stories(
    with_state: 'started',
    fields: story_fields
  )
  work_in_progress_json = work_in_progress.map { |story| to_story_json story }

  demo = project.stories(
    with_state: 'finished',
    fields: story_fields
  ) + project.stories(
    with_state: 'delivered',
    fields: story_fields
  )
  demo_json = demo.map { |story| to_story_json story }

  done = project.stories(
    with_state: 'accepted',
    fields: story_fields,
    accepted_after: (DateTime.now - 7).iso8601
  ).reverse
  done_json = done.map { |story| to_story_json story }

  impeded = project.stories(
    with_label: 'impeded',
    fields: story_fields,
  )
  impeded_json = impeded.map { |story| to_story_json story }

  send_event('pivotal_upcoming', { stories: upcoming_json })
  send_event('pivotal_wip', { stories: work_in_progress_json })
  send_event('pivotal_demo', { stories: demo_json })
  send_event('pivotal_done', { stories: done_json })
  send_event('pivotal_impeded', { stories: impeded_json })
end

