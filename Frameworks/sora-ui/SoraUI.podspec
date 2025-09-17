#
# Be sure to run `pod lib lint SoraUI.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SoraUI'
  s.version          = '1.10.3'
  s.summary          = 'UI Library for design and layout process simplification.'

  s.description      = 'Library contains views and controls that simplifies design and layout implementation manually in code or utilizing interface build.'

  s.homepage         = 'https://github.com/sora-xor'
  s.license          = { :type => 'GPL 3.0', :file => 'LICENSE' }
  s.author           = { 'ERussel' => 'emkil.russel@gmail.com' }
  s.source           = { :git => 'https://github.com/soramitsu/UIkit-iOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.swift_version = '5.0'

  s.subspec 'AdaptiveDesign' do |as|
      as.source_files = 'SoraUI/Classes/AdaptiveDesign/**/*'
  end

  s.subspec 'Controls' do |cs|
      cs.dependency 'SoraUI/Animator'
      cs.source_files = 'SoraUI/Classes/Controls/**/*'
  end

  s.subspec 'LoadingView' do |ls|
      ls.dependency 'SoraUI/Controls'
      ls.source_files = 'SoraUI/Classes/LoadingView/**/*'
  end

  s.subspec 'PinView' do |ps|
      ps.dependency 'SoraUI/Controls'
      ps.source_files = 'SoraUI/Classes/PinView/**/*'
  end

  s.subspec 'Animator' do |anims|
    anims.source_files = 'SoraUI/Classes/Animator/**/*'
  end

  s.subspec 'DetailsView' do |details|
    details.dependency 'SoraUI/Controls'
    details.source_files = 'SoraUI/Classes/DetailsView/**/*'
  end

  s.subspec 'EmptyState' do |emptystate|
    emptystate.dependency 'SoraUI/Animator'
    emptystate.source_files = 'SoraUI/Classes/EmptyState/**/*'
  end

  s.subspec 'PageLoader' do |pageloader|
    pageloader.source_files = 'SoraUI/Classes/PageLoader/**/*'
  end

  s.subspec 'Camera' do |camera|
    camera.source_files = 'SoraUI/Classes/Camera/**/*'
  end

  s.subspec 'ModalPresentation' do |mp|
    mp.dependency 'SoraUI/Animator'
    mp.dependency 'SoraUI/Controls'
    mp.source_files = 'SoraUI/Classes/ModalPresentation/**/*'
  end

  s.subspec 'Skrull' do |skl|
    skl.source_files = 'SoraUI/Classes/Skrull/**/*'
  end

  s.subspec 'Helpers' do |views|
    views.source_files = 'SoraUI/Classes/Helpers/**/*'
  end

  s.test_spec do |ts|
      ts.source_files = 'Tests/**/*.swift'
  end

end
