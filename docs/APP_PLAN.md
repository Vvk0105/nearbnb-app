# NearBnB guest app: plan

## Scope (version 1)

Guest only, Android first. Hosts and admins use the website.

| Area | Screens | API |
|---|---|---|
| Explore | Home (search card, recently added, how it works), search sheet (where + suggestions, day, time, nights, guests), results (sort, filters, infinite scroll) | `/search`, `/search/suggest`, `/places/*`, `/meta/booking`, `/meta/listing` |
| Property | Photos, details, rooms, house rules, cancellation policy, reviews | `/properties/{id}`, `/properties/{id}/reviews` |
| Booking | Month calendar, time, nights, guests, live price, alternatives, confirm sheet with profile check | `/units/{id}/availability/calendar`, `/units/{id}/quote`, `/me/booking-readiness`, `/units/{id}/book` |
| Trips | List by group, trip detail: pay (Stripe PaymentSheet), withdraw, cancel (refund shown first), review, report a problem, host details and check-in instructions once confirmed | `/me/bookings*`, `/pay`, `/pay/sync`, `/cancel-preview`, `/cancel`, `/review`, `/issues` |
| Alerts | Notification list, unread badge, mark read, push notifications | `/me/notifications*`, `/me/notifications/devices` |
| Profile | Personal details and profile links, change password, terms and privacy, sign out, delete account, updated-terms gate | `/me`, `/me/social-links`, `/auth/change-password`, `/me/consents`, `/me/delete` |
| Sign-in | Login, sign up (terms), 6-digit email code, forgot and reset password | `/auth/*` |

Signed-out people can browse Explore and properties. Booking, Trips, Alerts and Profile ask them to sign in and bring
them back to where they were.

## Backend changes made for the app (nearbnb repo)

- Token sign-in for `X-Client: mobile` (cookies unchanged for the website), no captcha for the app.
- `POST /me/delete`: erases personal details, keeps anonymous booking and payment records (Google Play requirement).
- Public page `https://nearbnb.com/delete-account`.
- Push: `device_tokens` table, `/me/notifications/devices` and `/devices/remove`, Firebase sender in the email worker.

## Work flow

1. Code is generated and handed to the Flutter developer.
2. The developer runs `flutter analyze`, `flutter test`, builds, and tests on real phones.
3. Bugs come back with `docs/BUG_REPORT.md`; fixes go into the next build.
4. Releases go to Play **internal testing** first, then production.

## Later (not in version 1)

- iOS build and App Store release (needs a Mac or a cloud build service, and an Apple developer account).
- Host features in the app.
- Map view of search results (needs the Maps SDK and a key restricted to the app).
- Deep links from emails straight into the app (Android App Links: needs `assetlinks.json` on nearbnb.com).
- Profile photo upload from the app.
