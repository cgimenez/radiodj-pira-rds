require 'socket'
require 'readline'

hostname = '127.0.0.1'
port = 21100
LOG = "#{ENV['HOME']}/.rds_history"

if File.exist?(LOG)
  File.readlines(LOG).each do |line|
    Readline::HISTORY << line.chomp
  end
end

at_exit do
  File.open(LOG, 'w+') do |f|
    Readline::HISTORY.each do |line|
      f.puts line
    end
  end
end

while line = Readline.readline("SEND COMMAND > ", true)
  s = TCPSocket.open(hostname, port)
  s.puts "#{line}\r"
  s.close
end
