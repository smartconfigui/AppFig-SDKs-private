Pod::Spec.new do |s|
  s.name             = 'AppFig'
  s.version          = '2.0.0'
  s.summary          = 'AppFig iOS SDK - Client-side feature flags and remote configuration'
  s.description      = <<-DESC
    AppFig is a client-side feature engine for iOS apps.

    Features:
    - Local rule evaluation (zero latency)
    - Event-based targeting with sequences
    - User and device property targeting
    - Automatic caching and background sync
    - Offline-first architecture
    - A/B testing with automatic variant assignment
    - Multiple analytics provider support (Amplitude, Firebase, Mixpanel)
  DESC

  s.homepage         = 'https://appfig.com'
  s.license          = { :type => 'Proprietary', :text => 'Copyright (c) AppFig. All rights reserved.' }
  s.author           = { 'AppFig' => 'hello@appfig.com' }
  s.source           = { :git => 'https://github.com/AppFig/AppFig-SDKs.git', :tag => s.version.to_s }

  s.platform         = :ios
  s.ios.deployment_target = '12.0'

  s.source_files     = 'ios/AppFig/AppFig/**/*.swift'
  s.exclude_files    = 'ios/AppFig/AppFigTests/**/*'

  s.swift_version    = '5.0'
  s.requires_arc     = true

  s.documentation_url = 'https://appfig.com/docs/ios'
end
