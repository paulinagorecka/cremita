require 'octokit'
require 'jira'
require 'dotenv'
require 'colorize'
require "docopt"

Dotenv.load

$github = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

$jira = JIRA::Client.new({
  username: ENV["JIRA_USERNAME"],
  password: ENV["JIRA_PASSWORD"],
  site: ENV["JIRA_SITE"],
  auth_type: :basic,
  context_path: ''
})

def fetch_commits(repository, start_tag, end_tag)
  commits = commits_between_tags(repository, start_tag, end_tag)
  puts "INFO: #{commits.length} commits in #{repository} between #{start_tag} and #{end_tag}"
  commits
end

def commits_between_tags(repo, start_tag, end_tag)
  $github.compare(repo, start_tag, end_tag).commits
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
  commits.map{ |commit|
    commit.commit.message.scan(/[A-Z]+-\d+/)
  }.flatten.uniq
end

def jira_issues_by_ids(jira_issue_ids)
  if jira_issue_ids.empty?
    []
  else
    $jira.Issue.jql("issuekey in (#{jira_issue_ids.join(', ')})")
  end
end

def jira_parent_issues_ids(jira_issues)
  jira_issues.map { |jira_issue| get_jira_parent_id(jira_issue) }.uniq
end

def get_jira_parent_id(jira_issue)
  begin
    jira_issue.parent["key"]
  rescue NoMethodError => e
    jira_issue.key
  end
end

def group_by_jira_parent(jira_issues)
  jira_issues.group_by { |jira_issue|
    get_jira_parent_id(jira_issue)
  }
end

def filter_by_task_status(jira_issues, issue_status)
  jira_issues.select { |jira_issue| jira_issue.status.name.eql?(issue_status) }
end

def filter_by_task_type(jira_issues, issue_type)
  jira_issues.select { |jira_issue| jira_issue.issuetype.name.eql?(issue_type) }
end

def draw_issue(issue, child=false)
  colors = {
    "yellow" => :yellow,
    "green" => :green,
    "blue-gray" => :blue,
  }

  types = {
    "Bug" => "🐞 ",
    "Story" => "📘 ",
    "Technical Task" => "🔨 ",
    "Technical Story" => "🔨 ",
    "Improvement" => "👻 ",
    "Buglet" => "🐞 ",
  }

  key = issue.key
  type = types[issue.issuetype.name]
  status = issue.status.name.colorize(colors[issue.status.statusCategory["colorName"]])
  indent = child ? "    " : ""
  url = "#{ENV["JIRA_SITE"]}/browse/#{issue.key}".underline
  url_line = child ? "" : "\n#{indent}#{url}"

  name = issue.summary
  if name.length > 50
    name = name[0..47] + "..."
  end

  "#{indent}#{key} [#{status} #{type}] #{name}#{url_line}"
end

def draw_jira_issue_groups(grouped_issues)
  grouped_issues.each { |parent, issues|
    puts ""

    issue = issues.find{ |issue| issue.key == parent }
    puts draw_issue(issue)

    issues.select{ |issue| issue.key != parent }.map { |issue|
      puts draw_issue(issue, true)
    }
  }
end

def github_issue_ids_in_commits(commits)
  commits.select{ |commit|
    /I-(\d+)/.match(commit.commit.message)
  }.map{ |commit|
    /I-(\d+)/.match(commit.commit.message)[1]
  }.flatten.uniq
end

def draw_github_issue_ids(repository, commits)
  issue_ids = github_issue_ids_in_commits(commits)

  unless issue_ids.empty?
    puts ''
    puts 'Github issues:'
  end

  issue_ids.each{ |issue_id|
    url = "https://github.com/#{repository}/issues/#{issue_id}".underline
    puts "##{issue_id}: #{url}"
  }
end


doc = <<DOCOPT
Cremita

Usage:
  cremita.rb <repository> <start> <end> [options]

  -t --tasks          Filter output by Jira tasks, no substaks.
  --status STATUS     Filter output by Jira task status.
  --type TYPE         Filter output by Jira task type.

DOCOPT

begin
  options = Docopt::docopt(doc)
rescue Docopt::Exit => e
  puts e.message
end

exit 1 if options.nil?

repository = options["<repository>"]
start_tag = options["<start>"]
end_tag = options["<end>"]
jira_tasks = options["--tasks"]
jira_tasks_status = options["--status"]
jira_task_type = options["--type"]

unless jira_tasks_status.nil? || jira_task_type.nil?
  jira_tasks = true
end


commits = fetch_commits(repository, start_tag, end_tag)
commits = fetch_commits(repository, end_tag, start_tag) if commits.empty?

jira_issues = jira_issues_in_commits(commits)

jira_tasks = jira_parent_issues(jira_issues)
jira_subtasks = jira_child_issues(jira_issues)

jira_issues_list = jira_tasks.eql?(true) ? jira_tasks : (jira_tasks + jira_subtasks)

jira_issues_list = filter_by_task_status(jira_issues_list, jira_tasks_status) unless jira_tasks_status.nil?
jira_issues_list = filter_by_task_type(jira_issues_list, jira_task_type) unless jira_task_type.nil?

jira_grouped_issues = group_by_jira_parent(jira_issues_list)

draw_jira_issue_groups(jira_grouped_issues)
draw_github_issue_ids(repository, commits)