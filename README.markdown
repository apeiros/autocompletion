README
======


Summary
-------
This gem provides fast prefix-autocompletion in pure ruby.


Installation
------------
`gem install autocompletion`


Usage
-----

### Autocomplete words
    auto = AutoCompletion.words(%w[foo bar baz])
    auto.complete('f') # => ["foo"]
    auto.complete('b') # => ["bar", "baz"]
    auto.complete('z') # => []

### Autocomplete objects by attributes
    Person  = Struct.new(:first_name, :last_name)
    people  = [
      Person.new("Peter", "Parker"),
      Person.new("Luke", "Skywalker"),
      Person.new("Anakin", "Skywalker"),
    ]
    auto    = AutoCompletion.map(people) { |person|
      [person.first_name, person.last_name]
    }

    auto.complete("P")
    # => [#<struct Person first_name="Peter", last_name="Parker">]

    auto.complete("S")
    # => [#<struct Person first_name="Luke", last_name="Skywalker">,
    #     #<struct Person first_name="Anakin", last_name="Skywalker">]

    auto.complete("S", "L")
    # => [#<struct Person first_name="Luke", last_name="Skywalker">]


Links
-----

* __Github__          http://github.com/apeiros/autocompletion
* __Documentation__   http://rdoc.info/github/apeiros/autocompletion/master/frames
* __Rubygems__        http://rubygems.org/gems/autocompletion
