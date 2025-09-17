Pod::Spec.new do |s|
  s.name             = 'SCard'
  s.version          = '1.8.0'
  s.summary          = 'Description of Sora Card.'

  s.description      = <<-DESC
  You can start the card application and KYC procedure in all security and privacy, and order your SORA Card through Polkaswap.io, soracard.com, or SORA Wallet.
                       DESC

  s.homepage         = 'https://github.com/Soramitsu/SCard'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Soramitsu' => 'soracard@soramitsu.co.jp' }
  s.source           = { :git => 'https://github.com/sora-xor/sora-card-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'SCard/Classes/**/*'

  s.resources = "SCard/Assets/*.xcassets"
  s.frameworks = 'UIKit'
  s.dependency 'R.swift', '~> 6.1.0'
  s.dependency 'SnapKit'
  s.dependency 'SoraUIKit'#, '1.1.11'
  s.dependency 'PayWingsOAuthSDK', '2.0.2'
  s.dependency 'PayWingsKycSDK', '1.0.6'
  s.dependency 'IdensicMobileSDK' #, '2.2.5'

  # TODO: PW release IdensicMobileSDK to public pods
  # s.dependency 'IdensicMobileSDK', :http => 'https://github.com/PayWings/PayWingsOnboardingKycSDK-iOS-IdensicMobile/archive/v2.2.5.tar.gz'

end
