# PROJECT_NAME=my_project rails new bar --skip-bundle --skip-test-unit -d postgresql -m ~/Code/.rails/templates/new_app_template.rb

require 'rvm'
PROJECT_NAME    = ENV['PROJECT_NAME'] || ''
RVM_RUBY_STRING = RVM::Environment.current_ruby_string
RVM_RUBY_SHORT  = RVM_RUBY_STRING[/\d.\d.\d/, 0]

#require '~/Code/.rails/generators/thorough_actions.rb'

#
# git init:
#
git :init
git add:    '.',
    commit: " -m 'Initial commit'" \
            " -m 'note: rvm use #{RVM_RUBY_STRING}@#{app_name}\n" \
                 "      gem install -rN rails\n" \
                 "      rails new #{app_name} --skip-bundle --skip-test-unit -d postgresql'"

#
# .gitignore:
#
append_file '.gitignore',
            <<-GITIGNORE.gsub(/^ */, '')

            # VIM files
            .*sw?
            .idea
            .test
            *.orig

            # Emacs tags
            TAGS

            .DS_Store*

            doc/*
            !doc/README_FOR_APP
            .yardoc/
            GITIGNORE
git add: '.', commit: %Q{ -m 'Expand .gitignore' }

#
# Set up RVM and bundle:
#
file '.ruby-version',
     <<-CONTENTS.gsub(/^ */, '')
     #{RVM_RUBY_SHORT}
     CONTENTS

gemset_name = "%s#{app_name}" % [PROJECT_NAME.empty? ? '' : "#{PROJECT_NAME}-"]
file '.ruby-gemset',
     <<-CONTENTS.gsub(/^ */, '')
     #{gemset_name}
     CONTENTS

#run "rvm use #{RVM_RUBY_SHORT}@#{gemset_name} --create"
@env = RVM::Environment.new "#{RVM_RUBY_STRING}@#{gemset_name}"
@env.gemset_create gemset_name
@env.gemset_use! gemset_name

run %Q{ bundle install }
git add: '.', commit: %Q{ -m 'Set up RVM and bundle' }

#
# Database tools: use pg_power and power_enum, proper platforms:
#
gem 'power_enum'
gem 'pg_power'
gem 'activerecord-jdbcpostgresql-adapter', platforms: [:jruby]
# TODO: Fix to replace, not duplicate!:
gem 'pg', platforms: [:mri_18, :mri_19, :rbx]
run %Q{ bundle install }
git add: '.', commit: %Q{ -m 'Use pg_power and power_enum for advanced schema design; fix platform adapters' }

#
# RSpec:
#
gem_group :development, :test do
  gem 'rspec'
  gem 'rspec-rails'
end
run %Q{ bundle install }
generate 'rspec:install'
append_file '.rspec',
            <<-RSPEC_CONTENTS.gsub(/^ */, '')
            --format documentation
            --profile
            --backtrace
            --order random
            RSPEC_CONTENTS
git add:    '.',
    commit: " -m 'Add RSpec support; Tailor RSpec options'" \
            " -m 'note: rails generate rspec:install'"

#
# SimpleCov:
#
gem_group :test do
  gem 'colorize'           , require: false
  gem 'simplecov'          , require: false
  #
  #gem 'simplecov-rcov-text', require: false
  # Revert to released gem when merge of https://github.com/kina/simplecov-rcov-text/pull/3 has been tagged and released.
  gem 'simplecov-rcov-text', require: false, git: 'git@github.com:kina/simplecov-rcov-text.git'
  # Or just remove simplecov-rcov-text when this is merged: https://github.com/metricfu/metric_fu/pull/201
  #
end
run %Q{ bundle install }
inject_into_file 'spec/spec_helper.rb',
                 "\nrequire 'simplecov'\n\n",
                 before: %Q{require File.expand_path("../../config/environment", __FILE__)}

file '.simplecov', <<-'SIMPLECOV'
require 'simplecov-rcov-text'
require 'colorize'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::RcovTextFormatter,
  SimpleCov::Formatter::HTMLFormatter
]
SimpleCov.start do
  add_filter '/spec/'

  # Fail the build when coverage is weak:
  at_exit do
    SimpleCov.result.format!
    threshold, actual = 100.0, SimpleCov.result.covered_percent
    if actual < threshold then # FAIL
      msg = "\nLow coverage: "
      msg << "#{actual}%".colorize(:red)
      msg << ' is ' << 'under'.colorize(:red) << ' the threshold: '
      msg << "#{threshold}%.".colorize(:green)
      msg << "\n"
      $stderr.puts msg
      exit 1
    else # PASS
      # Precision: three decimal places:
      actual_trunc = (actual * 1000).floor / 1000.0
      msg = "\nCoverage: "
      msg << "#{actual}%".colorize(:green)
      if actual_trunc > threshold
        msg << ' is ' << 'over'.colorize(:green) << ' the threshold: '
        msg << "#{threshold}%. ".colorize(color: :yellow, mode: :bold)
        msg << 'Please update the threshold to: '
        msg << "#{actual_trunc}% ".colorize(color: :green, mode: :bold)
        msg << 'in ./.simplecov.'
      else
        msg << ' is ' << 'at'.colorize(:green) << ' the threshold: '
        msg << "#{threshold}%.".colorize(:green)
      end
      msg << "\n"
      $stdout.puts msg
    end
  end
end
SIMPLECOV

git add: '.', commit: %Q{ -m 'Add SimpleCov support' }

#
# MetricFu:
#
gem 'metric_fu', group: [:development, :test], require: false
run %Q{ bundle install }
run %Q{ metric_fu --no-open }
append_file '.gitignore',
            <<-GITIGNORE.gsub(/^ */, '')

            # exclude everything in tmp
            tmp/*
            # except the metric_fu directory
            !tmp/metric_fu/
            # but exclude everything *in* the metric_fu directory
            tmp/metric_fu/*
            # except for the _data directory to track metrical outputs
            !tmp/metric_fu/_data/
            GITIGNORE
git add: '.', commit: %Q{ -m 'Add MetricFu support; initial run' }

#
# Development tools:
#
gem_group :development do
  gem 'awesome_print' # Pretty print Ruby objects # Load in *_core, or just console?
  #gem 'rdiscount' # Markdown markup language in C # Use redcarpet instead
  gem 'redcarpet', require: false # safe Markdown parser
  gem 'yard', require: false # Ruby documentation tool
end
gem_group :development, :test do
  gem 'pry'    , require: false # IRB alternative and runtime developer console
  gem 'pry-doc', require: false # MRI Core documentation and source code for the Pry REPL
  gem 'pry-nav', require: false # Binding navigation commands for Pry to make a simple debugger
  gem 'randexp' # generates a random string for almost any regular expression
  gem 'ruby-prof' , require: false, platforms: [:mri]   # fast code profiler for Ruby
  gem 'jruby-prof', require: false, platforms: [:jruby] # fast code profiler for JRuby
  # Or pass -Xprofile to rubinius ...
end
git add: '.', commit: %Q{ -m 'Add Pry, AwesomePrint, randexp, Yard, etc. support' }
