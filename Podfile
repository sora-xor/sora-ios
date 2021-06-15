platform :ios, '12.0'

source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'SoraPassportAll' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'GCDWebServer', :inhibit_warnings => true
  pod 'SoraDocuments'
  #pod 'SoraCrypto', '~> 0.2.0'
  pod 'IrohaCrypto/secp256k1', :git => 'https://github.com/ArsenyZ/IrohaCrypto.git', :commit => 'c0a0022f0ee95b4e2d255ee108d7a73c257acde2'#, '= 0.7.4'
  pod 'IrohaCrypto/ed25519', :git => 'https://github.com/ArsenyZ/IrohaCrypto.git', :commit => 'c0a0022f0ee95b4e2d255ee108d7a73c257acde2'
  pod 'IrohaCrypto/Iroha', :git => 'https://github.com/ArsenyZ/IrohaCrypto.git', :commit => 'c0a0022f0ee95b4e2d255ee108d7a73c257acde2'
  #pod 'IrohaCrypto'
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => 'cc66cd7f9b30c5e3ec4992885efd3cd4c70606c1'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '29518e70c1a386405c19f2f335eaeef6d500c4ad'
  pod 'FirebaseMessaging'
  pod 'Firebase/Crashlytics'
  pod 'FirebaseAnalytics'
  pod 'ReachabilitySwift'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
  pod 'SwiftyBeaver'
  pod 'SKPhotoBrowser'
  pod 'SoraFoundation', '~> 0.8.0'
  #pod 'web3swift', :git => 'https://github.com/matter-labs/web3swift.git', :commit => '8b1001b8a336cdcf243d1771bf2040e8c82433cc'
  pod 'IKEventSource'
  pod 'Anchorage'
  pod 'Then'

  target 'SoraPassportTests' do
      inherit! :search_paths
      
      pod 'Cuckoo'
      pod 'FireMock'
      pod 'SoraUI'
      pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
      pod 'SoraDocuments'
     # pod 'SoraCrypto', '~> 0.2.0'
      pod 'IrohaCrypto/secp256k1', :git => 'https://github.com/ArsenyZ/IrohaCrypto.git', :commit => 'c0a0022f0ee95b4e2d255ee108d7a73c257acde2'#, '= 0.7.4'
      pod 'IrohaCrypto/ed25519', :git => 'https://github.com/ArsenyZ/IrohaCrypto.git', :commit => 'c0a0022f0ee95b4e2d255ee108d7a73c257acde2'
      pod 'IrohaCrypto/Iroha', :git => 'https://github.com/ArsenyZ/IrohaCrypto.git', :commit => 'c0a0022f0ee95b4e2d255ee108d7a73c257acde2'
      pod 'SoraKeystore'
      pod 'RobinHood'
   #   pod 'IrohaCrypto'
      pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => 'cc66cd7f9b30c5e3ec4992885efd3cd4c70606c1'
      pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '29518e70c1a386405c19f2f335eaeef6d500c4ad'
      pod 'SoraFoundation', '~> 0.8.0'
     # pod 'web3swift', :git => 'https://github.com/matter-labs/web3swift.git', :commit => '8b1001b8a336cdcf243d1771bf2040e8c82433cc'
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
