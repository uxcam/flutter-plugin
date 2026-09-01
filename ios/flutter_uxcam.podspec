#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_uxcam'
  s.version          = '2.10.0'
  s.summary          = 'UXCam flutter plugin.'
  s.description      = <<-DESC
UXCam flutter plugin
                       DESC
  s.homepage         = 'https://www.uxcam.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'UXCam Inc' => 'admin@uxcam.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_uxcam/Sources/flutter_uxcam/**/*.{h,m}'
  s.public_header_files = 'flutter_uxcam/Sources/flutter_uxcam/include/**/*.h'
  s.dependency 'Flutter'
  s.static_framework = true
  s.dependency 'UXCam', '~> 3.10.3'
  s.ios.deployment_target = '13.0'
end
