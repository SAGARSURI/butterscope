# For apps that still use CocoaPods; the sample app uses Swift Package
# Manager through ios/butterscope/Package.swift.
Pod::Spec.new do |s|
  s.name             = 'butterscope'
  s.version          = '0.0.1'
  s.summary          = 'Reads the phone state Butterscope stamps on a run.'
  s.homepage         = 'https://github.com/SAGARSURI/butterscope'
  s.license          = { :type => 'none' }
  s.author           = 'Butterscope'
  s.source           = { :path => '.' }
  s.source_files     = 'butterscope/Sources/butterscope/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
