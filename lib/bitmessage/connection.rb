module Bitmessage
  class Connection < EventMachine::Connection

    attr_reader :node, :connected

    COMMANDS = [:version, :verack, :addr, :inv, :getdata, :msg, :broadcast, :ping, :pong, :alert]
    COMMANDS_NOT_REQUIRING_HANDSHAKE = [:version, :verack]
    COMMANDS_REQUIRING_HANDSHAKE = COMMANDS - COMMANDS_NOT_REQUIRING_HANDSHAKE

    def initialize(node, client)
      super
      @node, @client = node, client
      @connected, @handshaked = false, false
      @data = ""
      @sent_verack, @received_verack = false, false
      @protocol_version = PROTOCOL_VERSION # Could be down-graded if peer uses an older protocol version.
      @remote_listening_port = nil
      @client.send(:conns) << self # Add this connection to the client.
    end

    def post_init
      send_version_message if outbound?
    end

    def connection_completed
      puts "Connection established with #{node.host}:#{node.port}."
      @connected = true
    end

    def receive_data(data)
      @data += data.force_encoding("binary") # Notice the data parameter passed to Message.parse() is expected to be encoded in binary.
      @data, *messages = Message.parse(@data)
      messages.each do |message|
        command = message.delete(:command)
        puts "Got '#{command}' from #{node.host}:#{node.port}."
        if COMMANDS_NOT_REQUIRING_HANDSHAKE.include?(command) || (COMMANDS_REQUIRING_HANDSHAKE.include?(command) && handshaked?)
          send(:"received_#{command}_message", message)
        else
          puts "Command not supported, or required handshake not yet established."
        end
      end
    end

    def unbind
      puts "Connection to #{node.host}:#{node.port} closed."
      node.failed_connection_time = Time.now unless @handshaked
      @client.send(:conns).reject! { |conn| conn == self } # Remove this connection from the client.
    end

    def outbound?
      !@node.nil?
    end

    def inbound?
      !outbound?
    end

    def handshaked?
      @handshaked
    end

    private

    # == Helpers to send messages. ==

    def send_version_message
      message = Message.create(
        :version,
        :dest_ip => @node.host, :dest_port => @node.port, :dest_services => @node.services,
        :src_ip => "0.0.0.0", :src_port => Client::LISTEN_ON_PORT, :src_services => Client::SERVICES_PROVIDED, # The :src_ip will be ignored by our peer.
        :nonce => @client.nonce
      )
      send_data message
    end

    def send_verack_message
      message = Message.create(:verack)
      @sent_verack = true
      send_data message
    end

    # == Event handlers on reception of messages. ==

    def received_version_message(message)
      return if @sent_verack # If this connection has already sent a verack, it means it has already gotten a version. Ignore this message.
      puts "Remote node useragent is #{message[:user_agent]}, interested in streams #{message[:streams]}."
      unless message[:streams].include?(STREAM)
        puts "This node is not interested in our stream of interest. Closing connection."
        close_connection
        return
      end
      if message[:nonce] == @client.nonce
        puts "We have just established a connection to ourself. Yuk! Closing it."
        close_connection
        return
      end
      @protocol_version = [message[:protocol_version], @protocol_version].min
      @remote_listening_port = message[:src_port]
      send_verack_message
      check_for_handshake_completion
    end

    def received_verack_message(message)
      @received_verack = true
      check_for_handshake_completion
    end

    def method_missing(*args) # TODO: temporary, remove once all received_*_message calls are implemented.
      puts "!!!! GOT A MESSAGE MISSING CALL #{args[0]} !!!!"
    end

    # == Other helpers. ==

    def broadcast_data(message)
      @client.broadcast_to_handshaked_connections(message)
    end

    # == Others. ==

    def check_for_handshake_completion
      if @sent_verack && @received_verack && !@handshaked
        @handshaked = true
        puts "Handshake completed for #{@node.host}:#{@node.port}."
        set_comm_inactivity_timeout(600) # As per the original implementation. A ping-pong mechanism exists to keep the connection alive.
        # TODO: Add the node if it is inbound.
        # TODO: tell all the nodes about this node.
        # TODO: tell this node about all the nodes.
        # TODO: close connection if we're above MAX_INBOUND_CONNECTIONS and this is inbound, and test. document: this is done here to share the nodes.
        # TODO: "sendBigInv"
      end
    end


  end
end
