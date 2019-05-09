# Ruby internal_api

This is a gem for decomposing monolithic Rails apps. It allows you to specify an internal class or module that serves as the internal api for another class or module.

Example:

```ruby
# Any class or module can be the interface for a portion of your app.
# Imagine trying to collect all payment-related code in your app such that you
# can guarantee none of it is used in surprising ways.

# You'll want to somehow encapsulate your models
class PaymentRecord < ActiveRecord::Base
  internal_api PaymentApi
end

# And any helper modules or classes
module Payments
  class Issue
    internal_api PaymentApi
  end
end

# And all you need is some object that you specify as the internal_api for all your code.
module PaymentApi
  def charge(amount_cents, options = {})
    # This is whatever bespoke, ugly code you've inherited in your existing app.
    record = PaymentRecord.create(amount_cents)
    issue = Payments::Issue.new(record).complete!
    log(issue)
  end
end

# So when someone adds a new dependency to your internal code they fail their unit tests:
module Onboarding
  def self.complete!(user)
    PaymentRecord.create(1_00, type: auth) 
    # other onboarding stuff
  end
end
Onboarding.complete(@user) #! Only `PaymentApi` methods can execute PaymentApi code.
```

The `internal_api` call rewrites the public methods on your internal code to
ensure that it can only be called if `PaymentApi` is somewhere in the call
stack. This allows you to hide an entire portion of your application behind an
interface of some kind and have confidence it's reasonable well encapsulated.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'internal_api'
```

## Performance

This API enforcement is purely dyamic - `internal_api` modified the runtime
execution of code and checks for correct access patterns. This has a nonzero
but completely negligible impact on performance and therefore can safely be run
in production.

If you come from a Java background you may be used to thinking of backtraces as
very expensive. In Ruby they're quite cheap - the backtrace is always available
in memory and accessing it only requires [turning](https://github.com/ruby/ruby/blob/c3cf1ef9bbacac6ae5abc99046db173e258dc7ca/vm_backtrace.c#L549-L566) the C stack into (simple) Ruby
objects.

Constructing a single backtrace in running production code takes only a few microseconds on any
modern CPU:

    >> Benchmark.measure { 1_000_000.times { Kernel.caller_locations }}.real
    => 5.190758000011556

## TODO

* [ ] Hardcode callers that we'll want to whitelist (e.g. Pry and Rails console)
* [ ] Introduce environment-specific options for erroring or warning
* [ ] An ActiveRecord extension (separate gem?) that records where associations and models are defined and doesn't permit crossing internal_api boundaries
* [ ] Exception lists of filenames as option arg to `.internal_api`

## Contributing

Patches welcome, forks celebrated. This project is a safe, welcoming space for collaboration, and contributors will adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InternalApi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/internal_api/blob/master/CODE_OF_CONDUCT.md).
