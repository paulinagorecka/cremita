cremita
====

[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)

Cremita is a simple script that looks up all commits between two commit
hashes or tags in a Github repository, finds all JIRA issue tags in the
commit messages and prints the current status of each issue and its parent.

We built this at [Typeform](https://github.com/typeform) as a quick and dirty
Friday hack to make quality assurance before deployments a little bit easier.

How do I install it?
----

1. Clone this repository.
2. Run `bundle install` to install its dependencies.
3. Create a `.env` file from the `.env.dist` file with your credentials.

How do I use it?
----

Just pass a repository name and a starting and ending hash as arguments.
For example:

```
bundle exec ruby cremita.rb example/foobar v1.0.0 34a8b99
```
