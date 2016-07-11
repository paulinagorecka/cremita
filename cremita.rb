require 'rubygems'
require 'bundler'
Bundler.setup(:default)

require 'octokit'
require 'jira'
require 'dotenv'
require 'colorize'
require 'docopt'

require_relative 'lib/cremita'

Cremita.new(argv: ARGV).run
