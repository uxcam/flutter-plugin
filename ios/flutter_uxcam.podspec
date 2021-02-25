#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_uxcam'
  s.version          = '1.3.2'
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
  s.dependency 'UXCam','~> 3.3.3'
  s.ios.deployment_target = '9.0'
end

