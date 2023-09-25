platform :ios, '13.0'

source 'https://github.com/soramitsu/SSFSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'SoraPassportAll' do
  use_frameworks!

  pod 'Sourcery', '~> 1.4'
  pod 'SwiftLint', '~> 0.49.0'
  pod 'R.swift', '~> 6.1.0'
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraDocuments'
  pod 'IrohaCrypto', '~> 0.9.0'
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'Kingfisher', :git => 'https://github.com/onevcat/Kingfisher', :branch => 'version6-xcode13', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :branch => 'feature/fearless-utils-for-sora'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :branch => 'feature/sora-propositions'
  pod 'FirebaseMessaging'
  pod 'Firebase/Crashlytics'
  pod 'FirebaseAnalytics'
  pod 'ReachabilitySwift'
  pod 'Starscream', :git => 'https://github.com/soramitsu/fearless-starscream.git', :branch => 'feature/without-origin'
  pod 'SwiftyBeaver'
  pod 'SoraFoundation'
  pod 'Anchorage'
  pod 'Then'
  pod 'lottie-ios', '~> 3.5.0'  
  pod 'Nantes'
  pod 'SnapKit'
  pod 'SoraUIKit', :git => 'https://github.com/soramitsu/ios-ui.git', :tag => '1.0.6'
  pod 'IdensicMobileSDK', :http => 'https://github.com/PayWings/PayWingsOnboardingKycSDK-iOS-IdensicMobile/archive/v2.2.1.tar.gz'
  pod 'SCard', :git => 'https://github.com/sora-xor/sora-card-ios', :branch => 'release/1.2.0'
  pod 'FLEX', :configurations => ['Debug', 'Dev']
  pod 'XNetworking', :podspec => 'https://raw.githubusercontent.com/soramitsu/x-networking/0.0.61/AppCommonNetworking/XNetworking/XNetworking.podspec'
  pod 'SSFCloudStorage'

  target 'SoraPassportTests' do
      inherit! :search_paths
      
      pod 'Cuckoo', '~> 1.9.1'
      pod 'FireMock'
      pod 'SoraUI'
      pod 'Starscream', :git => 'https://github.com/soramitsu/fearless-starscream.git', :branch => 'feature/without-origin'
      pod 'SoraDocuments'
      pod 'SoraKeystore'
      pod 'RobinHood'
      pod 'IrohaCrypto', '~> 0.9.0'
      pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :branch => 'feature/fearless-utils-for-sora'
      pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :branch => 'feature/sora-propositions'
      pod 'SoraFoundation'
      pod 'GoogleAPIClientForREST/Core'
      pod 'GoogleAPIClientForREST/Drive'
      pod 'XNetworking', :podspec => 'https://raw.githubusercontent.com/soramitsu/x-networking/0.0.61/AppCommonNetworking/XNetworking/XNetworking.podspec'
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
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        config.build_settings["DEVELOPMENT_TEAM"] = "YLWWUD25VZ"
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 9.0
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        end
      end
    end
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
        config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
        config.build_settings["DEVELOPMENT_TEAM"] = "YLWWUD25VZ"
        config.build_settings['CODE_SIGN_STYLE'] = "Manual"
        config.build_settings['CODE_SIGN_IDENTITY'] = "iPhone Developer"
    end
  end
end
