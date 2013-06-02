module Bitmessage
  class Node

    attr_reader :host, :port, :services
    attr_writer :failed_connection_time

    def initialize(host, port, services, client)
      @host, @port = host, port
      @services = services
      @client = client
      @failed_connection_time = nil
      @client.send(:nodes) << self # Add this node to the client.
    end

    def should_retry_connection?
      @failed_connection_time.nil? || (Time.now - @failed_connection_time > Client::MIN_CONNECTION_RERTY_TIME)
    end

    def delete
      @client.send(:nodes).reject! { |node| node == self } # Remove this node from the client.
    end

  end
end
