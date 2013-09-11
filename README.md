BatBugger
===============

This is the notifier gem for integrating apps with the : [BatBugger Exception Notifier for Ruby and Rails](http://batbugger.io).
Developed and Maintained by grepruby team: [Ruby and Rails Expert Team](http://grepruby.com).

## Installation

Add this line to your application's Gemfile:

    gem 'batbugger'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install batbugger

Also please create the initializer, that's simple enough.
Just put the code below in config/initializers/batbugger.rb

    Batbugger.configure({
      :api_key => '[your-api-key]',
      :environment_name => '[rails-env]'
    })

That's it!

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
