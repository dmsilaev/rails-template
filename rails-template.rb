
initializer 'generators.rb', <<-RUBY
Rails.application.config.generators do |g|
end
RUBY

@recipes = ["activerecord", "capybara", "git", "heroku", "jquery", "rspec", "sass"]

def recipes; @recipes end
def recipe?(name); @recipes.include?(name) end

def say_custom(tag, text); say "\033[1m\033[36m" + tag.to_s.rjust(10) + "\033[0m" + "  #{text}" end
def say_recipe(name); say "\033[1m\033[36m" + "recipe".rjust(10) + "\033[0m" + "  Running #{name} recipe..." end
def say_wizard(text); say_custom(@current_recipe || 'wizard', text) end

def ask_wizard(question)
  ask "\033[1m\033[30m\033[46m" + (@current_recipe || "prompt").rjust(10) + "\033[0m\033[36m" + "  #{question}\033[0m"
end

def yes_wizard?(question)
  answer = ask_wizard(question + " \033[33m(y/n)\033[0m")
  case answer.downcase
    when "yes", "y"
      true
    when "no", "n"
      false
    else
      yes_wizard?(question)
  end
end

def no_wizard?(question); !yes_wizard?(question) end

def multiple_choice(question, choices)
  say_custom('question', question)
  values = {}
  choices.each_with_index do |choice,i|
    values[(i + 1).to_s] = choice[1]
    say_custom (i + 1).to_s + ')', choice[0]
  end
  answer = ask_wizard("Enter your selection:") while !values.keys.include?(answer)
  values[answer]
end

@current_recipe = nil
@configs = {}

@after_blocks = []
def after_bundler(&block); @after_blocks << [@current_recipe, block]; end
@after_everything_blocks = []
def after_everything(&block); @after_everything_blocks << [@current_recipe, block]; end
@before_configs = {}
def before_config(&block); @before_configs[@current_recipe] = block; end



# >-----------------------------[ ActiveRecord ]------------------------------<

@current_recipe = "activerecord"
@before_configs["activerecord"].call if @before_configs["activerecord"]
say_recipe 'ActiveRecord'

config = {}
config['database'] = multiple_choice("Which database are you using?", [["MySQL", "mysql"], ["Oracle", "oracle"], ["PostgreSQL", "postgresql"], ["SQLite", "sqlite3"], ["Frontbase", "frontbase"], ["IBM DB", "ibm_db"]]) if true && true unless config.key?('database')
config['auto_create'] = yes_wizard?("Automatically create database with default configuration?") if true && true unless config.key?('auto_create')
@configs[@current_recipe] = config

if config['database']
  say_wizard "Configuring '#{config['database']}' database settings..."
  old_gem = gem_for_database
  @options = @options.dup.merge(:database => config['database'])
  gsub_file 'Gemfile', "gem '#{old_gem}'", "gem '#{gem_for_database}'"
  template "config/databases/#{@options[:database]}.yml", "config/database.yml.new"
  run 'mv config/database.yml.new config/database.yml'
end

after_bundler do
  rake "db:create:all" if config['auto_create']
end


# >-------------------------------[ Capybara ]--------------------------------<

@current_recipe = "capybara"
@before_configs["capybara"].call if @before_configs["capybara"]
say_recipe 'Capybara'


@configs[@current_recipe] = config

gem 'capybara', :group => [:development, :test]

after_everything do
  inject_into_file "spec/rails_helper.rb", after: "require 'rspec/rails'" do
<<-RUBY
# Capybara helpers
require 'capybara/rails'
require 'capybara/rspec'
RUBY
  end

  create_file "spec/features/home_spec.rb", <<-RUBY
require 'rails_helper'
describe 'visiting the homepage (sanity check)', type: :feature do
  it 'should have a body' do
    skip 'Only run when there is a root defined in routes'
    visit '/'
    page.should have_css('body')
  end
end
RUBY
end


# >----------------------------------[ Git ]----------------------------------<

@current_recipe = "git"
@before_configs["git"].call if @before_configs["git"]
say_recipe 'Git'

git :init

@configs[@current_recipe] = config

remove_file '.gitignore'
create_file '.gitignore' do
<<-GIT
!.keep
*.DS_Store
*.swo
*.swp
/.bundle
/.env
/.foreman
/coverage/*
/db/*.sqlite3
/log/*
/public/system
/public/assets
/tmp/*
/node_modules
GIT
end


# >--------------------------------[ Heroku ]---------------------------------<

@current_recipe = "heroku"
@before_configs["heroku"].call if @before_configs["heroku"]
say_recipe 'Heroku'

config = {}
config['create'] = yes_wizard?("Automatically create appname.heroku.com?") if true && true unless config.key?('create')
config['staging'] = yes_wizard?("Create staging app? (appname-staging.heroku.com)") if config['create'] && true unless config.key?('staging')
config['domain'] = ask_wizard("Specify custom domain (or leave blank):") if config['create'] && true unless config.key?('domain')
config['deploy'] = yes_wizard?("Deploy immediately?") if config['create'] && true unless config.key?('deploy')
@configs[@current_recipe] = config

heroku_name = app_name.gsub('_','')

after_everything do
  if config['create']
    say_wizard "Creating Heroku app '#{heroku_name}.heroku.com'"
    while !system("heroku create #{heroku_name}")
      heroku_name = ask_wizard("What do you want to call your app? ")
    end
  end

  system("heroku buildpacks:add https://github.com/heroku/heroku-buildpack-nodejs.git -a #{heroku_name}")

  if config['staging']
    staging_name = "#{heroku_name}-staging"
    say_wizard "Creating staging Heroku app '#{staging_name}.heroku.com'"
    while !system("heroku create #{staging_name}")
      staging_name = ask_wizard("What do you want to call your staging app?")
    end
    git :remote => "rm heroku"
    git :remote => "add production git@heroku.com:#{heroku_name}.git"
    git :remote => "add staging git@heroku.com:#{staging_name}.git"
    say_wizard "Created branches 'production' and 'staging' for Heroku deploy."

    system("heroku buildpacks:add https://github.com/heroku/heroku-buildpack-nodejs.git -a #{staging_name}")
  end

  unless config['domain'].blank?
    run "heroku addons:add custom_domains"
    run "heroku domains:add #{config['domain']}"
  end

  git :push => "#{config['staging'] ? 'staging' : 'heroku'} master" if config['create'] && config['deploy']
end


# >--------------------------------[ jQuery ]---------------------------------<

@current_recipe = "jquery"
@before_configs["jquery"].call if @before_configs["jquery"]
say_recipe 'jQuery'

gem 'jquery-rails'


# >---------------------------------[ RSpec ]---------------------------------<

@current_recipe = "rspec"
@before_configs["rspec"].call if @before_configs["rspec"]
say_recipe 'RSpec'


@configs[@current_recipe] = config

gem 'rspec-rails', :group => [:development, :test]

inject_into_file "config/initializers/generators.rb", :after => "Rails.application.config.generators do |g|\n" do
  "    g.test_framework = :rspec\n"
end

gsub_file 'Gemfile', /.*(spring).*/i, ''

after_bundler do
  generate 'rspec:install'
end

# >---------------------------------[ Jasmine ]---------------------------------<

say_recipe('Jasmine')

gem 'jasmine-rails', group: [:development, :test]

after_bundler do
  generate 'jasmine_rails:install'
  remove_file 'spec/javascripts/support/jasmine.yml'
  create_file 'spec/javascripts/support/jasmine.yml', <<FILE
# minimalist jasmine.yml configuration when leveraging asset pipeline
spec_files:
  - "**/*[Ss]pec.{js,es6,jsx}"
FILE
end

# >---------------------------------[ Browserify ]---------------------------------<

say_recipe('Browserify')

gem 'browserify-rails'

create_file 'package.json' do
  license = ask('What license to use?')
<<-JSON
{
  "name": "#{app_name}",
  "dependencies" : {
    "browserify": "~> 10.2.4",
    "browserify-incremental": "^3.0.1",
    "bower": "~> 0.10.0"
  },
  "devDependencies" : {
    "jasmine-react-helpers": ">= 0.2.2"
  },
  "license": "#{license}",
  "engines": {
    "node": ">= 0.10"
  }
}
JSON
end

after_bundle do
  run('npm install')
  generate 'bower_rails:initialize'
  git add: '.'
  git commit: '-m "Add bower config"'
end

# >---------------------------------[ Bower ]---------------------------------<

say_recipe('Bower')
gem 'bower-rails', '0.10.0'

# >---------------------------------[ React ]---------------------------------<


say_recipe('react-rails')

gem 'react-rails'
after_bundle do
  generate 'react:install'
  git add: '.'
  git commit: '-m "Add react"'
end

# >---------------------------------[ es6 ]---------------------------------<

say_recipe('es6')

gem 'sprockets', '>= 3.4.0'
gem 'sprockets-es6'

inject_into_file 'config/application.rb', after: 'require "sprockets/railtie"' do
  <<-ES6
  require "sprockets/es6"
  ES6
end

# >---------------------------------[ SASS ]----------------------------------<

@current_recipe = "sass"
@before_configs["sass"].call if @before_configs["sass"]
say_recipe 'SASS'


@configs[@current_recipe] = config

@current_recipe = nil

# >---------------------------------[ rake ]----------------------------------<

inject_into_file 'Rakefile', after: 'Rails.application.load_tasks' do
<<-RAKE
# Run jasmine tests right after
task :default do
  Rake::Task['spec:javascript'].execute
end
RAKE
end

# >---------------------------------[ CI ]----------------------------------<

say_recipe('CI')

create_file '.travis.yml' do
<<-TRAVIS
install:
  - bundle install
  - npm install
  - bundle exec rake bower:install
script:
  - bundle exec rake
TRAVIS
end

create_file '.circle.yml' do
<<-CIRCLE
dependencies:
  post:
    - npm install
    - bundle exec rake bower:install
test:
  oeverride:
    - bundle exec rake
CIRCLE
end

# >-----------------------------[ Run Bundler ]-------------------------------<


gsub_file 'Gemfile', /sqlite3/, 'pg'
gsub_file 'Gemfile', /byebug/, 'pry'

say_wizard "Running Bundler install. This will take a while."
run 'bundle install'
say_wizard "Running after Bundler callbacks."
@after_blocks.each{|b| config = @configs[b[0]] || {}; @current_recipe = b[0]; b[1].call}

@current_recipe = nil
say_wizard "Running after everything callbacks."
@after_everything_blocks.each{|b| config = @configs[b[0]] || {}; @current_recipe = b[0]; b[1].call}

# Finish it
git :add => '.'
git :commit => '-m "Initial Commit"'
