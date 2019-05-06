# Ruby internal_api

This is a gem for decomposing monolithic Rails apps. It allows you to specify an internal class or module that serves as the internal api for another class or module.

Example:

    # This is the api you present to other code within the monolith for
    # managing payment transactions.
    module PaymentApi
      def charge(amount_cents, options = {})
        # This is whatever bespoke, ugly code you've inherited in your existing app.
        record = PaymentRecord.create(amount_cents)
        issue = Payments::Issue.new(record).complete!
        log(issue)
      end
    end

    # The internal_api gem allows you to ensure that the above `PaymentApi`
    # module is the only way anyone can call your code.
    class PaymentRecord < ActiveRecord::Base
      internal_api PaymentApi
    end

    module Payments
      class Issue
        internal_api PaymentApi
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

## Contributing

Patches welcome, forks celebrated. This project is a safe, welcoming space for collaboration, and contributors will adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InternalApi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/internal_api/blob/master/CODE_OF_CONDUCT.md).
