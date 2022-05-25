platform :ios, '12.0'

source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'SoraPassportAll' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'GCDWebServer', :inhibit_warnings => true
  pod 'SoraDocuments'
  pod 'IrohaCrypto'
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'Kingfisher', :git => 'https://github.com/onevcat/Kingfisher', :branch => 'version6-xcode13', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'FearlessUtils'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :branch => 'feature/sora-propositions'
  pod 'FirebaseMessaging'
  pod 'Firebase/Crashlytics'
  pod 'FirebaseAnalytics'
  pod 'ReachabilitySwift'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
  pod 'SwiftyBeaver'
  pod 'SKPhotoBrowser'
  pod 'SoraFoundation'
  pod 'IKEventSource'
  pod 'Anchorage'
  pod 'Then'
  pod 'lottie-ios'
  pod 'Nantes'
  pod 'SnapKit'

  target 'SoraPassportTests' do
      inherit! :search_paths
      
      pod 'Cuckoo', '1.5.2'
      pod 'FireMock'
      pod 'SoraUI'
      pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
      pod 'SoraDocuments'
      pod 'SoraKeystore'
      pod 'RobinHood'
      pod 'IrohaCrypto'
      pod 'FearlessUtils'
      pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :branch => 'feature/sora-propositions'
      pod 'SoraFoundation'
  end
  
  target 'SoraPassportUITests' do
      inherit! :search_paths
  end

  target 'SoraPassportIntegrationTests'

  target 'SoraPassport'
  
end

post_install do |installer|
  installer.pods_project.build_configuration_list.build_configurations.each do |configuration|
    configuration.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  end
  installer.generated_projects.each do |project|
    project.build_configurations.each do |config|
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 9.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
      end
    end
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 9.0
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
          config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        end
      end
    end
  end
end
