# Adds the Lock Screen countdown (the GuardLiveActivity widget extension) to
# Runner.xcodeproj and turns it on in the app. Run from app/ios:
#
#   ruby scripts/live_activity.rb
#
# Kept out of the committed project until the App ID
# com.stanchion.guard.liveactivity exists (docs/LOCAL-REQUESTS.md), so a
# TestFlight build never trips on a bundle id Apple doesn't know. Idempotent.
# Needs the xcodeproj gem.
require_relative 'extensions'

project, app = GuardExtensions.open
shared = GuardExtensions.shared_file(project, 'GuardActivityAttributes.swift')

# Live Activities need iOS 16.2 for the content and staleness APIs.
GuardExtensions.add(project, app, name: 'GuardLiveActivity', suffix: 'liveactivity',
                                  shared: [shared], deployment: '16.2', entitlements: false)
project.build_configurations.each { |c| c.build_settings['GUARD_LIVE_ACTIVITY'] = 'YES' }

project.save
puts 'Lock Screen countdown enabled: GuardLiveActivity embedded in Runner.'
