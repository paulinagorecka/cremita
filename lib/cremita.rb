class Cremita
  def initialize
    Dotenv.load

    @github = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])

    @jira = JIRA::Client.new(username: ENV['JIRA_USERNAME'],
                             password: ENV['JIRA_PASSWORD'],
                             site: ENV['JIRA_SITE'],
                             auth_type: :basic,
                             context_path: '')
  end

  def fetch_commits(repository, start_tag, end_tag)
    commits = commits_between_tags(repository, start_tag, end_tag)
    puts "INFO: #{commits.length} commits in #{repository} between #{start_tag} and #{end_tag}"
    commits
  end

  def commits_between_tags(repository, start_tag, end_tag)
    @github.compare(repository, start_tag, end_tag).commits
  rescue Octokit::InvalidRepository, Octokit::Error => e
    puts "ERROR: #{e.message}"
    exit 1
  end

  def jira_issues_in_commits(commits)
    jira_issues_by_ids(jira_issue_ids_in_commits(commits))
  end

  def jira_parent_issues(jira_issues)
    jira_issues_by_ids(jira_parent_issues_ids(jira_issues))
  end

  def jira_child_issues(jira_issues)
    jira_issues.select { |jira_issue| get_jira_parent_id(jira_issue) != jira_issue.key }
  end

  def jira_issue_ids_in_commits(commits)
    commits.map { |commit| commit.commit.message.scan(/[A-Z\d]+-\d+/) }.flatten.uniq
  end

  def jira_issues_by_ids(jira_issue_ids)
    return [] if jira_issue_ids.empty?
    @jira.Issue.jql("issuekey in (#{jira_issue_ids.join(', ')})")
  end

  def jira_parent_issues_ids(jira_issues)
    jira_issues.map { |jira_issue| get_jira_parent_id(jira_issue) }.uniq
  end

  def get_jira_parent_id(jira_issue)
    jira_issue.parent['key']
  rescue NoMethodError => e
    jira_issue.key
  end

  def group_by_jira_parent(jira_issues)
    jira_issues.group_by do |jira_issue|
      get_jira_parent_id(jira_issue)
    end
  end

  def filter_by_task_status(jira_issues, issue_status)
    jira_issues.select { |jira_issue| jira_issue.status.name.eql?(issue_status) }
  end

  def filter_by_task_type(jira_issues, issue_type)
    jira_issues.select { |jira_issue| jira_issue.issuetype.name.eql?(issue_type) }
  end

  def draw_issue(issue, child = false, jira_issue_priority)
    colors = {
      'yellow' => :yellow,
      'green' => :green,
      'blue-gray' => :blue
    }

    types = {
      'Bug' => "🐞 ",
      'Story' => "📘 ",
      'Technical Task' => "🔨 ",
      'Technical Story' => "🔨 ",
      'Improvement' => "👻 ",
      'Buglet' => "🐞 "
    }

    key = issue.key
    type = types[issue.issuetype.name]
    status = issue.status.name.colorize(colors[issue.status.statusCategory['colorName']])
    priority = jira_issue_priority ? " - #{issue.priority.name}" : ''
    indent = child ? '    ' : ''
    url = "#{ENV['JIRA_SITE']}/browse/#{issue.key}".underline
    url_line = child ? '' : "\n#{indent}#{url}"

    name = issue.summary
    name = name[0..47] + '...' if name.length > 50

    "#{indent}#{key} [#{status}#{priority} #{type}] #{name}#{url_line}"
  end

  def draw_jira_issue_groups(grouped_issues, jira_issue_priority)
    grouped_issues.each do |parent, issues|
      puts ''

      issue = issues.find { |issue| issue.key == parent }
      puts draw_issue(issue, jira_issue_priority)

      issues.select { |issue| issue.key != parent }.map do |issue|
        puts draw_issue(issue, true, jira_issue_priority)
      end
    end
  end

  def github_issue_ids_in_commits(commits)
    commits.select do |commit|
      /I-(\d+)/.match(commit.commit.message)
    end.map do |commit|
      /I-(\d+)/.match(commit.commit.message)[1]
    end.flatten.uniq
  end

  def draw_github_issue_ids(repository, commits)
    issue_ids = github_issue_ids_in_commits(commits)

    unless issue_ids.empty?
      puts ''
      puts 'Github issues:'
    end

    issue_ids.each do |issue_id|
      url = "https://github.com/#{repository}/issues/#{issue_id}".underline
      puts "##{issue_id}: #{url}"
    end
  end

  def run
    doc = <<DOCOPT
Cremita

Usage:
  cremita.rb <repository> <start> <end> [options]

  -t --tasks          Filter output by Jira tasks, no substaks.
  -p --priority       Show issues priority.
  --status STATUS     Filter output by Jira task status.
  --type TYPE         Filter output by Jira task type.

DOCOPT

    begin
      options = Docopt.docopt(doc)
    rescue Docopt::Exit => e
      puts e.message
    end

    exit 1 if options.nil?

    repository = options['<repository>']
    start_tag = options['<start>']
    end_tag = options['<end>']
    jira_tasks_only = options['--tasks']
    jira_issue_priority = options['--priority']
    jira_tasks_status = options['--status']
    jira_task_type = options['--type']

    jira_tasks_only = true unless jira_tasks_status.nil? || jira_task_type.nil?

    commits = fetch_commits(repository, start_tag, end_tag)
    commits = fetch_commits(repository, end_tag, start_tag) if commits.empty?

    jira_issues = jira_issues_in_commits(commits)

    jira_tasks = jira_parent_issues(jira_issues)
    jira_subtasks = jira_child_issues(jira_issues)

    jira_issues_list = jira_tasks_only.eql?(true) ? jira_tasks : (jira_tasks + jira_subtasks)

    jira_issues_list = filter_by_task_status(jira_issues_list, jira_tasks_status) unless jira_tasks_status.nil?
    jira_issues_list = filter_by_task_type(jira_issues_list, jira_task_type) unless jira_task_type.nil?

    jira_grouped_issues = group_by_jira_parent(jira_issues_list)

    draw_jira_issue_groups(jira_grouped_issues, jira_issue_priority)
    draw_github_issue_ids(repository, commits)
  end
end
