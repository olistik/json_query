# JsonQuery

Simple queries against JSON-like in-memory data structures.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "json_query"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install json_query

## Usage

```ruby
require "json_query"
data = {
  "foo" => "bar",
  "spam" => {
    "eggs" => [
      {"name" => "qui", "password" => "x"},
      {"name" => "quo", "password" => "y"},
      {"name" => "qua", "password" => "z"}
    ]
  }
}
JsonQuery.perform(data: data, query: "oo")
# => [{:path=>"foo", :value=>"bar"}]
JsonQuery.perform(data: data, query: "foo")
# => [{:path=>"foo", :value=>"bar"}]
JsonQuery.perform(data: data, query: "sp.egg[nam=qui].pass")
# => [{:path=>"spam.eggs[0].password", :value=>"x"}]
JsonQuery.perform(data: data, query: "sp.egg[nam=qui]")
# => [{:path=>"spam.eggs[0]", :value=>:set}]
JsonQuery.perform(data: data, query: "sp.egg[nam=qui]", deep: true)
# => [{:path=>"spam.eggs[0]", :value=>{"name"=>"qui", "password"=>"x"}}]
JsonQuery.perform(data: data, query: "sp.eggs", deep: true)
# => [{:path=>"spam.eggs", :value=>[{"name"=>"qui", "password"=>"x"}, {"name"=>"quo", "password"=>"y"}, {"name"=>"qua", "password"=>"z"}]}]
JsonQuery.perform(data: data, query: "sp.egg[1].name")
# => [{:path=>"spam.eggs[1].name", :value=>"quo"}]
JsonQuery.perform(data: data, query: "sp.egg[name=qu&pass=x].name")
# => [{:path=>"spam.eggs[0].name", :value=>"qui"}]
JsonQuery.perform(data: data, query: "asd")
# => []
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olistik/json_query. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

Made with <3 by [olistik](https://olisti.co).

GNU Affero General Public License (AGPL) version 3

- [gnu.org](https://www.gnu.org/licenses/agpl-3.0.txt)
- [repository copy](agpl-3.0.txt)
