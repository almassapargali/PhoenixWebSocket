Pod::Spec.new do |s|
  s.name         = 'PhoenixWebSocket'
  s.version      = '1.0'
  s.license      = 'MIT'
  s.summary      = 'A websockets framework designed to work with Phoenix Framework'
  s.homepage     = 'https://github.com/serejahh/PhoenixWebSocket'
  s.author       = 'Almas Sapargali'

  s.source       = { :git => 'https://github.com/serejahh/PhoenixWebSocket.git', :tag => s.version }
  s.source_files = 'PhoenixWebSocket/*'
  s.platform     = :ios, '9.0'
  s.dependency 'Starscream', '~> 2.0'
end
