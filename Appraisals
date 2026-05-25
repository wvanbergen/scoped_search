['6.0', '6.1', '7.0'].each do |version|
  appraise "rails-#{version}" do
    gem 'actionview', "~> #{version}.0"
    gem 'activerecord', "~> #{version}.0"
    eval_gemfile 'modular/rails-6'
    eval_gemfile 'modular/rspec'
  end

  appraise "rails-#{version}-activesupport" do
    gem 'actionview', "~> #{version}.0"
    gem 'activerecord', "~> #{version}.0"
    gem 'activesupport', "~> #{version}.0"
    eval_gemfile 'modular/rails-6'
    eval_gemfile 'modular/rspec'
  end
end
