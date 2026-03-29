source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 1.4"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use SolidQueue for background job processing
gem "solid_queue"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing
  gem "rspec-rails"

  # Ruby code formatter and linter
  gem "standard", require: false
end

group :development do
  # Development specific gems go here
end

# PDF generation
gem "prawn"
gem "prawn-table"

# Passwords
gem "bcrypt"

# Markdown processing
gem "redcarpet"

gem "importmap-rails", "~> 2.2"
gem "turbo-rails", "~> 2.0"

# Image processing
gem "image_processing", "~> 1.12"

# QR code generation
gem "rqrcode"

# Environment variables
gem "dotenv-rails"

# CSV support for Ruby 3.4+
gem "csv"

# ZIP file creation
gem "rubyzip"

gem "rails-controller-testing", "~> 1.0", groups: [:development, :test]
