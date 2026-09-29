# Adds the three Screen Time extensions to Runner.xcodeproj and switches the
# app to its Screen Time entitlements. Run from app/ios:
#
#   ruby scripts/screen_time.rb
#
# CI runs this for the Screen Time build; the committed project stays
# without it, so a TestFlight build works before the extension App IDs
# exist. Idempotent. Needs the xcodeproj gem.
require_relative 'extensions'

EXTENSIONS = [
  # target name, bundle id suffix (docs/LOCAL-REQUESTS.md)
  ['GuardMonitor', 'monitor'],
  ['GuardShield', 'shieldconfig'],
  ['GuardShieldAction', 'shieldaction'],
].freeze

project, app = GuardExtensions.open
shared = GuardExtensions.shared_file(project, 'GateShared.swift')

EXTENSIONS.each do |name, suffix|
  GuardExtensions.add(project, app, name: name, suffix: suffix, shared: [shared])
end

app.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner-ScreenTime.entitlements'
end
project.build_configurations.each { |c| c.build_settings['GUARD_SCREEN_TIME'] = 'YES' }

project.save
puts "Screen Time enabled: #{EXTENSIONS.map(&:first).join(', ')} embedded in Runner."
