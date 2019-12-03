require './rds_input_handler'

File.open("debug.log", "r") do |f|
    f.each_line do |line|
        converted = RDJInputHandler.new(line)
        converted.conform!
        #converted.decode
        #puts converted.to_s
        puts "#{converted.decode.join('-')}"
        #puts converted.decode[1]
    end
end