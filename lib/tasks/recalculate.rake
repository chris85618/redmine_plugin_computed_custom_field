namespace :computed_custom_field do
  def computed_custom_field_ids(issue)
    issue.custom_field_values
         .select { |value| value.custom_field.is_computed? }
         .map(&:custom_field_id)
  end

  def computed_fields_snapshot(issue, cf_ids)
    cf_ids.index_with { |id| issue.custom_field_value(id) }
  end

  def computed_fields_changed?(issue)
    cf_ids = computed_custom_field_ids(issue)
    return false if cf_ids.empty?

    before = computed_fields_snapshot(issue, cf_ids)
    issue.send(:eval_computed_fields) # recalculate
    after  = computed_fields_snapshot(issue, cf_ids)
    changed = before != after

    issue.reload if changed

    changed
  end

  def save_issue(issue)
    issue.children.each { |child| save_issue(child) }
    issue.reload

    if computed_fields_changed?(issue)
      issue.save!
      Rails.logger.info "[CCF recalc] Issue ##{issue.id} computed fields changed"
    end
  rescue => e
    Rails.logger.error "[CCF recalc] Issue ##{issue.id} failed: #{e.message}"
  end

  desc 'Recalculate computed custom fields for existing issues'
  task :recalculate => :environment do
    unless Issue.private_method_defined?(:eval_computed_fields)
      abort "[CCF recalc] eval_computed_fields not found."
    end
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
