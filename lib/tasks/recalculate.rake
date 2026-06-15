namespace :computed_custom_field do
  def computed_custom_field_ids(issue)
    issue.custom_field_values
         .select { |value| value.custom_field.is_computed? }
         .map(&:custom_field_id)
  end

  def computed_fields_snapshot(issue, cf_ids)
    cf_ids.each_with_object({}) do |cf_id, snapshot|
      snapshot[cf_id] = issue.custom_field_value(cf_id)
    end
  end

  def computed_fields_changed?(issue)
    cf_ids = computed_custom_field_ids(issue)
    return false if cf_ids.empty?

    before = computed_fields_snapshot(issue, cf_ids)
    issue.valid? # before_validation recaculation without writing DB
    after  = computed_fields_snapshot(issue, cf_ids)

    before != after
  end

  def save_issue(issue)
    issue.children.each { |child| save_issue(child) }
    issue.reload
    issue.save! if computed_fields_changed?(issue)
  rescue => e
    Rails.logger.error "[CCF recalc] Issue ##{issue.id} failed: #{e.message}"
  end

  desc 'Recalculate computed custom fields for existing issues'
  task :recalculate => :environment do
    projects =
      if ENV['project_id'].present?
        Project.where(id: ENV['project_id'])
      else
        Project.active
      end

    projects.each do |project|
      project.issues.where(parent_id: nil).find_each do |issue|
        save_issue(issue)
      end
    end
  end
end
