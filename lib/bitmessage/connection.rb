module Bitmessage
  class Connection < EventMachine::Connection

    attr_reader :node, :connected

    def initialize(node, client)
      super
      @node, @client = node, client
      @connected = false
      @data = ""
      @sent_verack, @received_verack = false, false
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
      puts "Got data from #{node.host}:#{node.port} #{data.inspect}."
      @data += data
      @data, *messages = Message.parse(data)
      messages.each do |message|
        # TODO: process the message.
      end
    end

    def unbind
      puts "Connection to #{node.host}:#{node.port} closed."
      node.failed_connection_time = Time.now unless @connected
      @client.send(:conns).reject! { |conn| conn == self } # Remove this connection from the client.
    end

    def outbound?
      !@node.nil?
    end

    def inbound?
      !outbound?
    end

    private

    def send_version_message
      message = Message.create(
        :version,
        :dest_ip => @node.host, :dest_port => @node.port, :dest_services => @node.services,
        :src_port => Client::LISTEN_ON_PORT, :nonce => @client.nonce
      )
      send_data message
    end

  end
end
