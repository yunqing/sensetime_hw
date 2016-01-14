#!/usr/bin/env ruby
require 'socket'
require 'pry'
require 'logger'
require 'optparse'
require 'pathname'

class Session
  STATE_INIT = 0
  STATE_USER = 1
  STATE_LOGIN = 2
  STATE_PASV = 20
  STATE_TRANSMITTING = 3
  STATE_CLOSED = 4

  RESP_SUCCESS_ACCEPT = "220 Welcome!\r\n"
  RESP_SUCCESS_USER = "331 Please specify the password.\r\n"
  RESP_SUCCESS_PASS = "230 Login successful.\r\n"
  RESP_SUCCESS_CWD = "250 Directory successfully changed.\r\n"
  RESP_SUCCESS_QUIT = "221 Goodbye!\r\n"

  RESP_SUCCESS_PREFIX_TYPE = "200 Switching to "
  NAME_TYPE_I = "Binary mode."
  NAME_TYPE_A = "ASCII mode."
  FLAG_TYPE_I = "I"
  FLAG_TYPE_A = "A"

  RESP_SUCCESS_START_LIST = "150 Here comes the directory listing.\r\n"
  RESP_SUCCESS_END_LIST = "226 Directory send OK.\r\n"

  RESP_SUCCESS_START_RETR = "150 Opening data connection\r\n"
  RESP_SUCCESS_END_RETR = "226 Transfer complete.\r\n"
  
  RESP_SUCCESS_START_STOR = "150 Opening data connection\r\n" # ? not sure about the response number and content
  RESP_SUCCESS_END_STOR = "226 Transfer complete.\r\n"
  
  RESP_SUCCESS_PREFIX_SIZE = "213 "
  RESP_SUCCESS_PREFIX_PWD = "257 "
  RESP_SUCCESS_PREFIX_PASV = "227 Entering passive mode "

  RESP_FAIL_PREFIX_NOSUPPORT = "502 "

  RESP_SUFFIX = "\r\n"

  def initialize(dir, server, logger, socket_cmd, host)
    @dir = dir
    @server = server
    @logger = logger
    @socket_cmd = socket_cmd
    @host = host
    @binary_flag = FLAG_TYPE_A
  end

  def welcome
    send_msg(RESP_SUCCESS_ACCEPT)
    @session_state = STATE_INIT 
  end
  
  def handle_client
    loop do
      cmd_read = @socket_cmd.recv(4096)
      unless cmd_read == ""
        @logger.info("Read buffer:" + cmd_read)
        cmds = parse_cmd(cmd_read)
        cmds.each do |cmd|
          process_cmd(cmd)
        end
      end
      if @session_state == STATE_CLOSED
        break
      end
    end
    p "end of function handle_client"
  end

  def close
    p "session #{self} close" # ? should do sth. else?
  end
  
  def process_cmd(_cmd)
    #binding.pry
    cmd, arg = _cmd.split(" ")

    if cmd == "USER"
      process_USER cmd, arg
    elsif cmd == "PASS"
      process_PASS cmd, arg
    elsif cmd == "PASV"
      process_PASV cmd, arg
    elsif cmd == "PWD"
      process_PWD cmd, arg
    elsif cmd == "CWD"
      process_CWD cmd, arg
    elsif cmd == "LIST"
      process_LIST cmd, arg
    elsif cmd == "SIZE"
      process_SIZE cmd, arg
    elsif cmd == "TYPE"
      process_TYPE cmd, arg
    elsif cmd == "RETR"
      process_RETR cmd, arg
    elsif cmd == "STOR"
      process_STOR cmd, arg
    elsif cmd == "QUIT"
      process_QUIT cmd, arg
    else
      @logger.info("unsupported command #{cmd}")
      send_msg(RESP_FAIL_PREFIX_NOSUPPORT + RESP_SUFFIX) 
    end

  end


  def process_USER(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_INIT
      if arg == "anonymous"
        @session_state = STATE_USER
        send_msg(RESP_SUCCESS_USER)
      end
    elsif @session_state == STATE_USER
      p "? how to handle" # ?
    elsif @session_state == STATE_CLOSED
      p "? session closed" # ?
    else
      p "alread logged in" # ?
    end
  end
  
  def process_PASS(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_USER
      if arg == nil || true
        @session_state = STATE_LOGIN
        send_msg(RESP_SUCCESS_PASS)
      end
    end
  end

  def process_PASV(cmd, arg)
    begin
    
     @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_LOGIN
       @logger.info("Recv cmd: " + cmd + " " + arg.to_s + "in process_PASV")
      # prepare a port
      _socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM)
      sockaddr = Socket.pack_sockaddr_in(0, @host)
      _socket.bind(sockaddr)
      #binding.pry
      host, port = _socket.local_address.ip_unpack
      x = port / 256
      y = port % 256
      msg = "#{RESP_SUCCESS_PREFIX_PASV} (#{host.split(".").join(",")},#{x},#{y})\r\n"
      _socket.listen(1)
      send_msg(msg)

      @socket_data, address = _socket.accept() # ? return a new socket again?
      p "here1", _socket.local_address
      p "here2", @socket_data, address
      #@socket_data.send("This message is send from data channel of server.", 0)

      # send the port to the client
      # wait on this port
      @session_state = STATE_PASV
      @logger.info("Recv cmd: " + cmd + " " + arg.to_s + "end in  process_PASV")
    end

    rescue => detail
        print detail.backtrace.join("\n")
    end

  end

  def process_LIST(cmd, arg)
    begin

    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_PASV
      @logger.info("Recv cmd: " + cmd + " " + arg.to_s + "in process_LIST")
      ret = `ls -al #{@dir}`
      send_msg(RESP_SUCCESS_START_LIST)
      @session_state = STATE_TRANSMITTING
      @logger.info("before send list")
      @socket_data.send(ret, 0)
      @socket_data.shutdown(Socket::SHUT_RDWR)
      @socket_data.close
      #binding.pry
      @logger.info("after send list")
      send_msg(RESP_SUCCESS_END_LIST)
      @session_state = STATE_LOGIN
      #binding.pry
      @logger.info("Recv cmd: " + cmd + " " + arg.to_s + "end in process_LIST")
    end

    rescue => detail
        print detail.backtrace.join("\n")
    end
  end

  def process_PWD(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_LOGIN

      ret = File.expand_path(@dir)
      resp = "#{RESP_SUCCESS_PREFIX_PWD}\"#{ret}\"#{RESP_SUFFIX}"
      send_msg(resp) 
      @logger.info("Sent: " + resp)
      #binding.pry
    end
  end

  def process_CWD(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    #binding.pry
    if @session_state == STATE_LOGIN
      if Pathname.new(arg).absolute?
        @dir = arg
        #binding.pry
      else
        @dir = File.expand_path(File.join(@dir, arg))
        p "not absolute"
      end
      send_msg(RESP_SUCCESS_CWD) 
    end
  end
  def process_SIZE(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_LOGIN
      if Pathname.new(arg).absolute?
        fn = arg
      else
        fn = File.join(@dir, arg)
      end
      size = File.stat(fn).size
      send_msg(RESP_SUCCESS_PREFIX_SIZE + size.to_s + RESP_SUFFIX)
    end
  end

  def process_TYPE(cmd, arg)

    begin


    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_LOGIN
      #send_msg("504 TYPE switch failed.")
      #return
      if arg == FLAG_TYPE_I
        name = NAME_TYPE_I
        @binary_flag = FLAG_TYPE_I
      elsif arg == FLAG_TYPE_A
        name = NAME_TYPE_A
        @binary_flag = FLAG_TYPE_A
      end
      send_msg(RESP_SUCCESS_PREFIX_TYPE + name + RESP_SUFFIX)
    end


    rescue => detail
      print detail.backtrace.join("\n")
    end
  end

  def process_RETR(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    if @session_state == STATE_PASV
      if Pathname.new(arg).absolute?
        fn = arg
      else
        fn = File.join(@dir, arg)
      end
      #binding.pry
      # open file
      data = File.read(fn, mode: "rb")
      send_msg(RESP_SUCCESS_START_RETR)
      @session_state = STATE_TRANSMITTING
      @socket_data.write(data)
      @socket_data.shutdown(Socket::SHUT_RDWR)
      send_msg(RESP_SUCCESS_END_RETR)
      @session_state = STATE_LOGIN
    end

  end
  def process_STOR(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    #binding.pry
    if @session_state == STATE_PASV
      if Pathname.new(arg).absolute?
        fn = arg
      else
        fn = File.join(@dir, arg)
      end
      send_msg(RESP_SUCCESS_START_STOR)
      @session_state = STATE_TRANSMITTING
      data = ""
      loop do
        _tmp = @socket_data.recv(4096)
        if _tmp == ""
          break
        end
        data = data + _tmp
      end
      #binding.pry
      File.open(fn, 'w') { |file| file.write(data) }
      #@socket_data.shutdown(Socket::SHUT_RDWR)
      @socket_data.close
      send_msg(RESP_SUCCESS_END_STOR)
      @session_state = STATE_LOGIN
    end

  end
  def process_QUIT(cmd, arg)
    @logger.info("Recv cmd: " + cmd + " " + arg.to_s)
    send_msg(RESP_SUCCESS_QUIT)
    @session_state = STATE_CLOSED
  end
  private

  def parse_cmd(cmds)
    cmds.split("\r\n")
  end

  def send_msg(msg)
    @socket_cmd.send(msg, 0)
  end
end

class FTPServer
  CMD_USER_anonymous = "USER anonymous\r\n"
  CMD_PASS_empty = "PASS \r\n"
  CMD_PASV = "PASV\r\n"
  CMD_LIST = "LIST\r\n"
  CMD_QUIT = "QUIT\r\n"
  CMD_PREFIX_USER = "USER "
  CMD_PREFIX_PASS = "PASS "
  CMD_PREFIX_SIZE = "SIZE "
  CMD_PREFIX_RETR = "RETR "
  CMD_PREFIX_STOR = "STOR "
  CMD_SUFFIX = "\r\n"

  def initialize(dir)
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @dir = File.expand_path(dir)
  end

  def bind(port, host)
    @port = port
    @host = host
    @socket_listen = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM)
    sockaddr = Socket.pack_sockaddr_in(port, host)
    @socket_listen.bind(sockaddr)
    @socket_listen.listen(5) #? What number should be used here?
  end

  def listen
    loop do
      p 'Waiting for new connection'
      socket, address = @socket_listen.accept()
      # create a new thread here to handle the new client
      Thread.start([@dir, self, @logger, socket, @host, address]) { |arg| 
        dir, server, logger, socket, host, address = arg
        p @host, address
        session = Session.new(dir, server, logger, socket, host)
        session.welcome
        session.handle_client
        session.close
        p "end in the block given to thread"
        #p server, socket, address
      }
      p "loop end in listen"
      #binding.pry
    end
  end



  def close
    @socket_listen.close
  end

end

def run_server(port, host, dir)
  server = FTPServer.new(dir)
  server.bind(port.to_i, host)
  server.listen
  server.close
  #binding.pry
end

def parse_argument
  options = {}
  argparser = OptionParser.new do |opts|
    opts.banner = "Usage: client.rb [options]"
    opts.on("-pPORT", "--port=PORT", "listen port") do |v|
      options[:port] = v
    end
    opts.on("--host=HOST", "binding address") do |v|
      options[:host] = v
    end
    opts.on("--dir=DIR", "change current directory") do |v|
      options[:dir] = v
    end
    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options[:verbose] = v
    end
    opts.on("-h", "print help") do
      puts argparser
      exit
    end
  end
  argparser.parse!
  mandatory = [:port, :host, :dir]
  missing = mandatory.select{ |param| options[param].nil? }
  unless missing.empty?
    puts "Missing options: #{missing.join(', ')}"
    puts argparser
    exit
  end
  p options
  p ARGV
  return options
end

def main
  opt = parse_argument
  run_server opt[:port], opt[:host], opt[:dir]
end

main
