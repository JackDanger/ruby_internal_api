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
    Onboarding.complete(@user) #! InternalApiViolationError: Onboarding must use `PaymentApi` methods to execute PaymentApi code.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'internal_api'
```

## Contributing

Patches welcome, forks celebrated. This project is a safe, welcoming space for collaboration, and contributors will adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InternalApi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/internal_api/blob/master/CODE_OF_CONDUCT.md).
