require 'octokit'
require 'jira'
require 'dotenv'
require 'colorize'

Dotenv.load

$github = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

$jira = JIRA::Client.new({
  username: ENV["JIRA_USERNAME"],
  password: ENV["JIRA_PASSWORD"],
  site: ENV["JIRA_SITE"],
  auth_type: :basic,
  context_path: ''
})

def commits_between_tags(repo, start_tag, end_tag)
  $github.compare(repo, start_tag, end_tag).commits
end

def issue_ids_in_commits(commits)
  commits.map{ |commit|
    commit.commit.message.scan(/[A-Z]+-\d+/)
  }.flatten.uniq
end

def issues_by_ids(issue_ids)
  if issue_ids.empty?
    []
  else
    $jira.Issue.jql("issuekey in (#{issue_ids.join(', ')})")
  end
end

def parent_issue_ids(issues)
  issues.map { |issue| get_parent_id(issue) }.uniq
end

def bugs_in_issues(issues)
  issues.select { |issue| issue.issuetype.name.eql?('Bug') }  
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

def fetch_commits(repository, start_tag, end_tag)
  commits = commits_between_tags(repository, start_tag, end_tag)
  puts "#{commits.length} commits in #{repository} between #{start_tag} and #{end_tag}"
  commits
end

def issues_for_commits(commits)
  issues_by_ids(issue_ids_in_commits(commits))
end

def parent_issues(issues)
  issues_by_ids(parent_issue_ids(issues))
end

def group_by_parent(issues)
  issues.uniq { |issue|
    issue.key
  }.group_by { |issue|
    get_parent_id(issue)
  }
end

def get_parent_id(issue)
  begin
    issue.parent["key"]
  rescue NoMethodError => e
    issue.key
  end
end

def draw_issue_groups(grouped_issues)
  grouped_issues.each { |parent, issues|
    puts ""

    issue = issues.find{ |issue| issue.key == parent }
    puts draw_issue(issue)

    issues.select{ |issue| issue.key != parent }.map { |issue|
      puts draw_issue(issue, true)
    }
  }
end

def draw_closed_issues(issues)
  issues.select { |issue| 
    issue.status.name.eql?('Closed')
  }.each { |closed_issue|
    puts ""
    puts draw_issue(closed_issue)
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

if ARGV.length < 3
  puts "Usage: cremita.rb <repository> <start> <end>"
  exit 1
end

repository = ARGV[0]
start_tag = ARGV[1]
end_tag = ARGV[2]
options = ARGV[3]

commits = fetch_commits(repository, start_tag, end_tag)
commits = fetch_commits(repository, end_tag, start_tag) if commits.empty?

issues = issues_for_commits(commits)
parents = parent_issues(issues)

grouped_issues = group_by_parent(issues + parents)

if options.nil?
  draw_issue_groups(grouped_issues) 
  draw_github_issue_ids(repository, commits)
elsif options.include?('-closed')
  parents = bugs_in_issues(parents) if options.include?('-bugs')
  draw_closed_issues(parents)
end
