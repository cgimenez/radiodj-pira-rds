#
# RDS PIRA32 daemon driver for RadioDJ
# Christophe Gimenez 2016
#

require 'rubygems'
require 'socket'
require 'thread'
require 'readline'
require 'logger'
#require 'serialport' 	# for old Pira 32 devices
require 'rubyserial' 	#

require './rds_input_handler'

class String
  def black;          "\033[30m#{self}\033[0m" end
  def red;            "\033[31m#{self}\033[0m" end
  def green;          "\033[32m#{self}\033[0m" end
  def brown;          "\033[33m#{self}\033[0m" end
  def blue;           "\033[34m#{self}\033[0m" end
  def magenta;        "\033[35m#{self}\033[0m" end
  def cyan;           "\033[36m#{self}\033[0m" end
  def gray;           "\033[37m#{self}\033[0m" end
  def yellow;         "\033[33m#{self}\033[0m" end
  def bg_black;       "\033[40m#{self}\033[0m" end
  def bg_red;         "\033[41m#{self}\033[0m" end
  def bg_green;       "\033[42m#{self}\033[0m" end
  def bg_brown;       "\033[43m#{self}\033[0m" end
  def bg_blue;        "\033[44m#{self}\033[0m" end
  def bg_magenta;     "\033[45m#{self}\033[0m" end
  def bg_cyan;        "\033[46m#{self}\033[0m" end
  def bg_gray;        "\033[47m#{self}\033[0m" end
  def bold;           "\033[1m#{self}\033[22m" end
  def reverse_color;  "\033[7m#{self}\033[27m" end
  def no_colors
    self.gsub /\033\[\d+m/, ""
  end
end

module ColorText

  def info(msg)
    puts msg.bold.yellow
  end

  def merror(msg)
    puts msg.bold.red
  end

end

class RdsRT

  include ColorText

  STATION_SHORT = "STATION"
  STATION_LONG  = "LONG STATION"
  STATION_PI    = "XXXX"
  TCP_PORT    = 21100
  USB_SERIAL  = "/dev/ttyUSB0"

  STATE_NONE            = 0
  STATE_CLEAR_INFO      = 1
  STATE_STATION_INFO    = 2
  STATE_PROGRAM_INFO    = 3
  STATE_PROGRAM_ENDING  = 4

  STATE_STATION_INFO_EVERY    = 20
  STATE_PROGRAM_INFO_EVERY    = 30

  COMMANDS = [
    'last',
    'reset',
    'help',
    'quit'
  ]

  def initialize()
    @daemonized = false
    @info_state = nil
    @refresh_rt = nil
    @server = nil
    @prev_info = nil
    @new_info = nil
    @prev_text = ''
    @dev_mode = false
    @refresh_rt = false
    @mutex = Mutex.new
    @info_state = STATE_CLEAR_INFO
    @program_duration = nil
    @program_started_at = nil
    @sport = nil
    @last_info_update = nil
    @last_long_pi_update = nil
    @logger = Logger.new(File.open('log.txt', "a+"), 1, 1024000)
    @log_mode = false
  end

  def log_info(msg, stdout = false)
    @logger.info(msg)
    info(msg) if stdout
  end

  def log_error(msg, stdout = false)
    @logger.error(msg)
    merror(msg) if stdout
  end

  #
  # open PIRA32 Serial Port
  #
  def open_pira()
    return if @dev_mode
    log_info "Opening Pira32 on #{USB_SERIAL}", true
    #@sport = SerialPort.new(USB_SERIAL, bauds: 2400, data_bits: 8, stop_bits: 1, parity: SerialPort::NONE, flush_output: true)
    @sport = Serial.new(USB_SERIAL, 2400, 8)
  end

  #
  # send PIRA32 command on Serial Port
  #
  def send_pira(data)
    if @dev_mode
      puts "DEV MODE send_pira #{data}"
    else
      log_info "#{data}"
      @sport.write("#{data}\r")
    end
  end

  #
  # close PIRA32 Serial Port
  #
  def close_pira()
    return if @dev_mode
    log_info "Closing Pira32", true
    @sport.close
  end

  #
  # Set dev Mode
  # If TRUE nothing will be sent to the Pira
  #
  def set_dev_mode(state)
    log_info("Running in dev mode, nothing will be send to the Pira32", true) if state
    @dev_mode = state
  end

  def set_daemonized(flag)
  	log_info("Running in daemon mode", true) if flag
    @daemonized = flag
    trap("INT") {} unless flag
  end

  def set_log_mode(flag)
    @log_mode = flag
  end

  #
  # access refresh_rt variable state
  #
  def get_refresh_rt
    result = false
    @mutex.synchronize do
      result = @refresh_rt
    end
    result
  end

  #
  # update refresh_rt variable state
  #
  def set_refresh_rt(state)
    @mutex.synchronize do
      @refresh_rt = state
    end
  end

  #
  # send text to Pira32
  # Latest song name is logged
  #
  def send_pira_rtext(text, is_a_song = true)
    if is_a_song
      open('last.txt', 'w') do |f|
        f.puts text
      end
    end
    send_pira("RT1=#{text}")
    send_pira("DPS1=#{text}")
    @last_info_update = Time.now
  end

  def clear_pira_rtext()
    send_pira_rtext('')
  end

  #
  # Decode RadioDJ string
  # Returns RDS text, category and length of broadcasting content
  #
  def decode_radio_dj(data)
    converted = RDJInputHandler.new(data)
    converted.conform!
    artist, title, category, duration = converted.decode
    text = ''
    if artist.size > 0 && title.size > 0
      text = "#{artist} - #{title}"
    elsif artist.size > 0 || title.size > 0
      text = "#{artist}#{title}"
    end
    return text, category, duration
  end

  #
  # RDS heartbeat
  #
  def rt_updater
    info "THREAD: Starting RT_UPDATER"
    clear_pira_rtext
    while true
      begin
        if get_refresh_rt
          text, category, @program_duration = decode_radio_dj(@new_info)
          if category == 0 || category == 4
            send_pira_rtext(text)
            @info_state = STATE_PROGRAM_INFO
            @prev_text = text
            @program_started_at = Time.now
          else
            @info_state = STATE_CLEAR_INFO
            @program_started_at = nil
          end
          set_refresh_rt false
        else
          sleep(0.3)
          elapsed = Time.now - @last_info_update
          if @program_started_at
            elapsed_since_program_start = Time.now - @program_started_at
            if @program_duration - elapsed_since_program_start < 30
              @info_state = STATE_CLEAR_INFO
              @program_started_at = nil
            end
          end

          case @info_state
          when STATE_NONE
          when STATE_CLEAR_INFO
            clear_pira_rtext
            @info_state = STATE_NONE

          when STATE_PROGRAM_INFO
            if elapsed > 20
              send_pira_rtext(STATION_LONG, false)
              @info_state = STATE_STATION_INFO
            end

          when STATE_STATION_INFO
            if elapsed > 30
              send_pira_rtext(@prev_text)
              @info_state = STATE_PROGRAM_INFO
            end
          end
        end
      rescue Exception => e
        clear_pira_rtext
        log_error("Exception : #{e.message}", true)
        log_error("Backtrace : #{e.backtrace}")
        raise
      end
    end
  end

  #
  # Single client TCP Server
  #
  def tcp_server
    info "THREAD: Opening TCP server on port #{TCP_PORT}"
    @server = TCPServer.open(TCP_PORT)
    while true
      client = @server.accept
      @last_info = @new_info
      @new_info = client.gets
      if @log_mode
        log_info("RCVD #{@new_info}")
        open('debug.log', 'a+') do |f|
          f.puts @new_info
        end
      end
      set_refresh_rt true
      client.close
    end
  end

  #
  # Execute prompt commands
  #

  def command_help
    COMMANDS.each do |command|
      puts command
    end
  end

  def command_last
    text = nil
    if @prev_info == nil
      text = File.readlines('last.txt')[0]
    else
      text = @prev_info
    end
    @mutex.synchronize do
      @new_info = text
      @refresh_rt = true
    end
  end

  def command_reset
    send_pira_rtext(STATION_LONG, false)
    @info_state = STATE_STATION_INFO
    @last_info_update = Time.now
  end

  #
  # Prompt's main loop
  #
  def prompt
    while line = Readline.readline("RDS > ", true)
      ar = line.split(' ')
      command = ar[0]
      if command
        command.downcase!
        if command == 'quit'
          return
        else
          if COMMANDS.include?(command)
            self.send "command_#{command}".to_sym
          else
            puts "Commande inconnue"
          end
        end
      end
    end
  end

  #
  # Reinit PIRA 32 encoder
  #
  def init
    log_info "Réinitialisation de l'encodeur RDS", true
    open_pira
    ["*PS=#{STATION_SHORT}", "*PI=#{STATION_PI}", "*RT1EN=1", "*DPS1EN=1"].each do |cmd|
      send_pira(cmd)
      sleep(0.3)
    end
    close_pira
  end

  #
  #
  #
  def run
    log_info "Starting"
    open_pira()

    @tcp_thread = Thread.new do
      tcp_server
    end
    sleep(0.3)
    @updater_thread = Thread.new do
      rt_updater
    end
    sleep(0.3)
    if @daemonized
      while true do
      end
    else
        prompt
    end

    close_pira()
  end
end

Thread.abort_on_exception = true
STDOUT.sync = true

rds = RdsRT.new()
init_rds = false

ARGV.each do |arg|
  case arg.downcase
    when 'init' # Reinit PIRA 32
      init_rds = true
    when 'log' # Keep log of all data received from RadioDJ
      rds.set_log_mode(true)
    when 'dev' # debug/dev mode - Nothing will be sent to the PIRA 32
      rds.set_dev_mode(true)
    when 'daemon' # No prompt
      rds.set_daemonized(true)
  end
end

if init_rds
  rds.init
else
  open('rds.pid', 'w') do |f| # keep pid just in case
    f.puts Process.pid
  end
  rds.run()
end
