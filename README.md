# Kashout

![Kashout](docs/brand/logo.png)

**An open-source SwiftUI rewards-app prototype.**

[MIT license](LICENSE) · [Contributing](CONTRIBUTING.md)

Kashout explores daily rewards, animated reward-box reveals and a points-based
redemption interface. The source includes onboarding, account screens,
Firebase integration, rewarded-ad integration and StoreKit subscription code.

## Current status

Source prototype, not a ready-to-run app or a live rewards service. The
repository contains Swift files but no Xcode project, dependency manifest or
Firebase configuration. Production ad identifiers are placeholders. Payouts,
backend enforcement and a published app have not been verified.

## Explore the source

- `Kashout/Views/`: onboarding, home, rewards, subscriptions and reveal screens.
- `Kashout/ViewModels/`: authentication and reward-flow state.
- `Kashout/Services/`: Google Mobile Ads and StoreKit adapters.
- `Kashout/Models/`: user and reward-box data structures.
- `Kashout/Config/Constants.swift`: prototype settings and placeholders.

A development setup needs a new Xcode SwiftUI app target, these source files,
and compatible Firebase Core/Auth/Firestore and Google Mobile Ads dependencies.
Use your own development configuration and test identifiers. Dependency
versions and end-to-end behavior still need validation before a working build
can be promised. Never commit service credentials.

## Contributions

A reproducible Xcode project and pinned dependencies are the first useful
improvements, followed by automated tests and a documented demo mode. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Third-party libraries retain their own licenses.
