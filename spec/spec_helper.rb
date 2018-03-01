# frozen_string_literal: true

require 'fakeredis/rspec'
require 'support/swag_spec'
require 'support/mvi/stub_mvi'
require 'support/spec_builders'
require 'support/schema_matchers'
require 'support/spool_helpers'
require 'support/fixture_helpers'
require 'support/spec_temp_files'
require 'support/have_deep_attributes_matcher'
require 'support/be_a_uuid'
require 'support/impl_matchers'
require 'support/negated_matchers'
require 'support/stub_emis'
require 'pundit/rspec'

# By default run SimpleCov, but allow an environment variable to disable.
unless ENV['NOCOVERAGE']
  require 'simplecov'

  SimpleCov.start 'rails' do
    track_files '{app,lib}/**/*.rb'
    add_filter 'config/initializers/sidekiq.rb'
    add_filter 'config/initializers/statsd.rb'
    add_filter 'config/initializers/mvi_settings.rb'
    add_filter 'config/initializers/clamscan.rb'
    add_filter 'config/initializers/config.rb'
    add_filter 'lib/data_migrations/uuid_unique_index.rb'
    add_filter 'lib/tasks/support/shell_command.rb'
    add_filter 'lib/config_helper.rb'
    add_filter 'lib/feature_flipper.rb'
    add_filter 'lib/vic/configuration.rb'
    add_filter 'spec'
    add_filter 'vendor'
    SimpleCov.minimum_coverage_by_file 90
    SimpleCov.refuse_coverage_drop
  end
end

# This file was generated by the `rails generate rspec:install` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause
# this file to always be loaded, without a need to explicitly require it in any
# files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider making
# a separate helper file that requires the additional dependencies and performs
# the additional setup, and require it from the spec files that actually need
# it.
#
# The `.rspec` file also contains a few flags that are not defaults but that
# users commonly want.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  # fix for test rspec test randomization when using spring
  # https://github.com/rails/spring/issues/113#issuecomment-135896880
  config.seed = srand % 0xFFFF unless ARGV.any? { |arg| arg =~ /seed/ }
  config.order = :random
  Kernel.srand config.seed

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.example_status_persistence_file_path = 'tmp/specs.txt'

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    # Some specs stub out `YAML.load_file`, which I18n uses to load the
    # translation files. Because rspec runs things in random order, it's
    # possible that the YAML.load_file that's stubbed out for a spec
    # could actually be called by I18n if translations are required before
    # the functionality being tested. Once loaded, the translations stay
    # loaded, so we may as well take the hit and load them right away.
    # Verified working on --seed 11101, commit e378e8
    I18n.locale_available?(:en)
  end

  config.include SpecBuilders
  config.include SpoolHelpers
  config.include FixtureHelpers

  config.around(:example, :run_at) do |example|
    Timecop.freeze(Time.zone.parse(example.metadata[:run_at]))
    example.run
    Timecop.return
  end
end
