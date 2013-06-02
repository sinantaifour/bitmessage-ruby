module Bitmessage
  class Client

    HOUSEKEEPING_INTERVAL = 1
    MAX_OUTBOUND_CONNECTIONS = 8
    MAX_INBOUND_CONNECTIONS = 100
    MIN_CONNECTION_RERTY_TIME = 30
    LISTEN_ON_PORT = 8444

    attr_reader :nonce

    def initialize
      @nodes = [] # TODO: should be eventually passed in.
      @conns = []
      @nonce = Random.rand(2 ** 64) # Used to stop this client from connecting to itself.
      bootstrap_nodes
    end

    def run!
      EventMachine.run do
        EventMachine::PeriodicTimer.new(HOUSEKEEPING_INTERVAL) { housekeeping! }
      end
    end

    private

    attr_accessor :nodes, :conns

    def bootstrap_nodes # Assume the bootstraped nodes provide the services that we provide.
      # == Hard-coded nodes. ==
      Node.new('109.91.57.2', 8443, Message::SERVICES_PROVIDED, self)
      Node.new('66.65.120.151', 8080, Message::SERVICES_PROVIDED, self)
      Node.new('188.18.69.115', 8443, Message::SERVICES_PROVIDED, self)
      Node.new('204.236.246.212', 8444, Message::SERVICES_PROVIDED, self)
      Node.new('85.177.81.73', 8444, Message::SERVICES_PROVIDED, self)
      Node.new('78.81.56.239', 8444, Message::SERVICES_PROVIDED, self)
      Node.new('204.236.246.212', 8444, Message::SERVICES_PROVIDED, self)
      # == Bootstrap from DNS. ==
      begin
        address_infos = Addrinfo.getaddrinfo('bootstrap8080.bitmessage.org', nil)
        address_infos.map { |ai| ai.ip_address }.uniq.each do |host|
          Node.new(host, 8080, Message::SERVICES_PROVIDED, self)
        end
        address_infos = Addrinfo.getaddrinfo('bootstrap8444.bitmessage.org', nil)
        address_infos.map { |ai| ai.ip_address }.uniq.each do |host|
          Node.new(host, 8444, Message::SERVICES_PROVIDED, self)
        end
      rescue SocketError => e
        # Silently ignore when the addresses cannot be resolved.
      end
    end

    def housekeeping!
      # == Initiate outbound connections. ==
      outbound = @conns.select(&:outbound?)
      if outbound.length < MAX_OUTBOUND_CONNECTIONS
        puts "Attempting more connections, currently at #{outbound.length}/#{MAX_OUTBOUND_CONNECTIONS}."
        candidates = (@nodes - outbound.map(&:node)).select(&:should_retry_connection?)
        candidates.sort_by { rand }[0...(MAX_OUTBOUND_CONNECTIONS - outbound.length)].each do |node|
          puts "Connecting to #{node.host}:#{node.port}."
          EventMachine.connect node.host, node.port, Connection, node, self
        end
      end
      # == More ... ==
      # (Nothing at the moment)
    end

  end
end
