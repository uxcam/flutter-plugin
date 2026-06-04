#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_uxcam'
  s.version          = '2.8.2'
  s.summary          = 'UXCam flutter plugin.'
  s.description      = <<-DESC
UXCam flutter plugin
                       DESC
  s.homepage         = 'https://www.uxcam.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'UXCam Inc' => 'admin@uxcam.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.static_framework = true

  s.vendored_frameworks = 'UXCam.xcframework'

  s.frameworks = 'AVFoundation', 'CoreGraphics', 'CoreMedia', 'CoreVideo',
                 'CoreTelephony', 'MobileCoreServices', 'QuartzCore',
                 'SystemConfiguration', 'Security', 'WebKit'
  s.libraries  = 'z', 'iconv', 'c++'

  s.user_target_xcconfig = {
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)" "/usr/lib/swift"'
  }

  s.ios.deployment_target = '12.0'
end
