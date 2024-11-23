# frozen_string_literal: true

source 'http://rubygems.org'
ruby '3.1.4'

## RAILS and related ##
gem 'rails', '~> 7.0.0'
gem 'puma'

## RAILS related ##
gem 'sass-rails', '~> 6.0'
gem 'terser', '~> 1.1', '>= 1.1.20'

## DATABASES ##
gem 'mysql2'

## CSS AND JAVASCRIPT ##
gem 'jquery-rails', '4.5.0'
gem 'jquery-ui-rails', '6.0.1'

## BOOTSTRAP & SIMPLE_FORM & FONTAWESOME ##
gem 'font-awesome-rails', '~> 4.7'
gem 'simple_form', '~> 5.1'

## TOOLS AND UTILITIES ##
gem 'audited', '~> 5.4', '>= 5.4.3'
gem 'cancancan', '~> 3.4'
gem 'devise', '~> 4.8', '>= 4.8.1'
gem 'email_validator', '~> 2.2', '>= 2.2.3'
gem 'kaminari', '~> 1.2', '>= 1.2.2'
gem 'liquid', '~> 5.4'
gem 'rails-settings-cached', '~> 2.8', '>= 2.8.2'
gem 'rsolr', '~> 2.5'
gem 'rufus-scheduler', '~> 3.8', '>= 3.8.2'
gem 'worldcatapi', git: 'https://github.com/taras-yorku/worldcatapi.git',
                   ref: 'ed6d0cb849e86a032dc84741a5d169da19b8e385'

gem 'caxlsx', '3.2.0'
gem 'caxlsx_rails', '0.6.3'

## EX LIBRIS INTEGRATION ALMA, PRIMO
gem 'alma', '~> 0.3.3'
gem 'primo', git: 'https://github.com/tulibraries/primo.git', branch: 'main'

## SEARCH - USING ELASTIC SEARCH
gem 'elasticsearch-model', '0.1.9'
gem 'elasticsearch-rails', '0.1.9'

## DUMP DATA INTO YML FILE ##
# rake db:data:dump_dir dir=../tmp/db_june_2017
gem 'yaml_db', '~> 0.7.0'

# NOTIFICATIONS
gem 'exception_notification', '~> 4.5'

## TESTING && DEVELOPMENT ##
gem 'rb-readline'

group :test do
  gem 'byebug', '~> 11.1', '>= 11.1.3'
  gem 'database_cleaner', '~> 2.0', '>= 2.0.1'
  gem 'factory_girl_rails', '4.8.0'
  gem 'guard-minitest', '2.4.6'
  gem 'minitest', '~> 5.16', '>= 5.16.3'
  gem 'minitest-around', '~> 0.5.0'
  gem 'shoulda-context', '~> 2.0'
  gem 'shoulda-matchers', '~> 5.1'
  gem 'sqlite3', '~> 1.4'
end

group :development do
  gem 'spring', '~> 4.0'
  gem 'web-console', '~> 4.2'
end

group :development, :test do
  gem 'faker', '~> 2.22'
  gem 'guard-bundler', '~> 3.0'
  gem 'guard-livereload', '~> 2.5', '>= 2.5.2', require: false
  gem 'populator', git: 'https://github.com/ryanb/populator.git'
end
