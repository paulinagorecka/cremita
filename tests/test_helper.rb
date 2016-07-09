require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)

require 'octokit'
require 'jira'
require 'dotenv'
require 'colorize'
require 'docopt'
require 'minitest/autorun'

require_relative '../lib/cremita'
