namespace :computed_custom_field do

  def save_issue(issue)
    issue.children.each { |child| save_issue(child) }
    issue.reload
    issue.save!
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
