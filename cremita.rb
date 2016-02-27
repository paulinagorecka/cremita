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
  issues.select { |issue|
    get_parent_id(issue) != nil
  }.map { |issue|
    issue.parent["key"]
  }
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
    "Technical Task" => "🛠 ",
    "Technical Story" => "🛠 ",
    "Improvement" => "👻 ",
    "Buglet" => "🐞 ",
  }

  key = issue.key
  type = types[issue.issuetype.name]
  status = issue.status.name.colorize(colors[issue.status.statusCategory["colorName"]])
  indent = child ? "    " : ""
  url = child ? "" : "\n#{indent}#{ENV["JIRA_SITE"]}/browse/#{issue.key}"

  name = child ? "" : issue.summary
  if name.length > 50
    name = name[0..47] + "..."
  end

  "#{indent}#{key} [#{status} #{type}] #{name}#{url}"
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
    get_parent_id(issue) || issue.key
  }
end

def get_parent_id(issue)
  begin
    issue.parent["key"]
  rescue NoMethodError => e
    nil
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

if ARGV.length != 3
  puts "Usage: cremita.rb <repository> <start> <end>"
  exit 1
end

repository = ARGV[0]
start_tag = ARGV[1]
end_tag = ARGV[2]

commits = fetch_commits(repository, start_tag, end_tag)
commits = fetch_commits(repository, end_tag, start_tag) if commits.empty?

issues = issues_for_commits(commits)
parents = parent_issues(issues)

grouped_issues = group_by_parent(issues + parents)
draw_issue_groups(grouped_issues)
