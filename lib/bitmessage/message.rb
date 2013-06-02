module Bitmessage
  class Message

    # The "data" parameter has to be encoded as binary.

    # This class is designed not to suffer from currently imposed limitations
    # in stream selection and services specification. For example, stream
    # numbers are passed in where appropriate (although the called would use
    # the currently hard-coded value).

    # This class assumes all IP addresses use IPv4.

    MAGIC_VALUE = "\xe9\xbe\xb4\xd9"
    COMMANDS = [:version, :verack, :addr, :inv, :getdata, :msg, :broadcast, :ping, :pong, :alert]
    MAX_PARSED_PAYLOAD_SIZE = 180000000 # Ignore messages with payloads bigger than 180MB, as per the original implementation.

    class << self

      def create(command, opts = {})
        # == Generate the payload depending on the message command. ==
        payload = case command
          when :version
            create_version_payload(
              opts[:dest_ip], opts[:dest_port], opts[:dest_services],
              opts[:src_ip], opts[:src_port], opts[:src_services],
              opts[:nonce]
            )
          when :verack
            create_verack_payload
          when :addr
            create_addr_payload
          when :inv
            create_inv_payload
          when :getdata
            create_getdata_payload
          when :msg
            create_msg_payload
          when :broadcast
            create_broadcast_payload
          when :ping
            create_ping_payload
          when :pong
            create_pong_payload
          when :alert
            create_alert_payload
        end
        # == Add the header. ==
        header = MAGIC_VALUE
        header += (command.to_s +  "\x00" * 12)[0...12]
        header += [payload.bytesize].pack("L>")
        header += sha512(payload)[0...4]
        header + payload
      end

      def parse(data) # Returns [data_post_consumption, message_1, message_2, ...].
        res = []
        data, message = parse_once(data)
        while message
          res << message
          data, message = parse_once(data)
        end
        [data, *res]
      end

      private

      def parse_once(data) # Returns [data_post_consumption, message].
        # == Run some preliminary tests. ==
        return [data, nil] if data.bytesize < 24 # Data is too small, don't consume anything.
        if data[0...4] != MAGIC_VALUE # Data doesn't start with MAGIC_VALUE, consume until next MAGIC_VALUE
          puts "Missing MAGIC_VALUE at the beginning of message. Ignoring."
          index = data.index(MAGIC_VALUE)
          data = index ? data[index..-1] : ""
          return [data, nil]
        end
        payload_length = data[16...20].unpack("L>").first
        return [data, nil] if data.bytesize < payload_length + 24 # Data is not complete yet.
        # == We have the full message, consume it and parse it. ==
        header = data[0...24]
        payload = data[24...(24 + payload_length)]
        data = data[(24 + payload_length)..-1] # Consume the message from data.
        if payload_length > MAX_PARSED_PAYLOAD_SIZE # Ignore messages with too big payloads.
          puts "Message payload bigger than MAX_PARSED_PAYLOAD_SIZE (#{MAX_PARSED_PAYLOAD_SIZE}). Ignoring."
          return [data, nil]
        end
        if sha512(payload)[0...4] != header[20...24] # Incorrect checksum, ignore full message.
          puts "Incorrect message checksum. Ignoring."
          return [data, nil]
        end
        command = header[4...16].gsub(/(\x00)*$/, "").to_sym
        unless COMMANDS.include?(command)
          puts "Incorrect command (#{command}). Ignoring."
          return [data, nil]
        end
        message = send(:"parse_#{command}_payload", payload)
        message[:command] = command if message
        [data, message]
      end

      # == Create payloads of individual message commands. ==

      def create_version_payload(dest_ip, dest_port, dest_services, src_ip, src_port, src_services, nonce)
        res = ""
        res += [PROTOCOL_VERSION].pack("L>")
        res += [src_services].pack("Q>")
        res += [Time.now.to_i].pack("q>")
        res += encode_net_addr(nil, dest_ip, dest_port, dest_services)
        res += encode_net_addr(nil, src_ip, src_port, src_services)
        res += [nonce].pack("Q>")
        res += encode_var_str("/bitmessage-ruby v#{VERSION}/")
        res += encode_var_int_list([STREAM])
        res
      end

      def create_verack_payload
        "" # The payload of a :verack message is an empty string.
      end

      def create_addr_payload
      end

      def create_inv_payload
      end

      def create_getdata_payload
      end

      def create_msg_payload
      end

      def create_broadcast_payload
      end

      def create_ping_payload
      end

      def create_pong_payload
      end

      def create_alert_payload
      end

      # == Parse payloads of individual message commads. ==

      def parse_version_payload(payload)
        res = {}
        res[:protocol_version], res[:services], res[:timestamp] = payload.unpack("L>Q>q>")
        payload = payload[20..-1]
        payload, dest = decode_net_addr(payload, false)
        payload, src = decode_net_addr(payload, false)
        res[:dest_ip], res[:dest_port], res[:dest_services] = dest[:ip], dest[:port], dest[:services]
        res[:src_ip], res[:src_port], res[:src_services] = src[:ip], src[:port], src[:services]
        res[:nonce] = payload.unpack("Q>").first
        payload = payload[8..-1]
        payload, res[:user_agent] = decode_var_str(payload)
        payload, res[:streams] = decode_var_int_list(payload)
        puts "Payload is longer than expected when parsing version message." if payload.length > 0
        res
      end

      def parse_verack_payload(payload)
        puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # A :verack message has no payload.
      end

      def parse_addr_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_inv_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_getdata_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_msg_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_broadcast_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_ping_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_pong_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      def parse_alert_payload(payload)
        # puts "Payload is longer than expected when parsing verack message." if payload.length > 0
        {} # TODO: return an actual message.
      end

      # === Data type helpers. ===
      # As defined in https://bitmessage.org/wiki/Protocol_specification.

      def encode_var_int(i)
        if i < 0xfd
          [i].pack("C")
        elsif i <= 0xffff
          [0xfd, i].pack("CS>")
        elsif i <= 0xffffffff
          [0xfe, i].pack("CL>")
        else
          [0xff, i].pack("CQ>")
        end
      end

      def encode_var_str(s)
        encode_var_int(s.bytesize) + s
      end

      def encode_var_int_list(arr)
        encode_var_int(arr.length) + arr.map { |i| encode_var_int(i) }.join("")
      end

      def encode_net_addr(stream, ip, port, services)
        res = ""
        if stream
          res += [Time.now.to_i].pack("Q>")
          res += [stream].pack("L>")
        end
        res += [services].pack("Q>")
        res += ([0x00] * 10 + [0xff] * 2 + ip.split(".").map { |i| i.to_i }).pack("C16") # Assuming ip contains an IPv4.
        res += [port].pack("S>")
      end

      def encode_inv_vector(obj)
        sha512(sha512(obj))[0...32]
      end

      def decode_var_int(data) # Returns [data_post_consumption, int].
        first_byte = data.unpack("C").first
        if first_byte < 0xfd
          consume = 1
          res = first_byte
        elsif first_byte == 0xfd
          consume = 3
          res = data.unpack("CS>").last # Avoid creating a new string with data[1..-1].
        elsif first_byte == 0xfe
          consume = 5
          res = data.unpack("CL>").last
        elsif first_byte == 0xff
          consume = 9
          res = data.unpack("CQ>").last
        end
        [data[consume..-1], res]
      end

      def decode_var_str(data) # Returns [data_post_consumption, str].
        data, length = decode_var_int(data)
        str = data[0...length]
        [data[length..-1], str]
      end

      def decode_var_int_list(data) # Returns [data_post_consumption, [int_1, int_2, ...]].
        res = []
        data, length = decode_var_int(data)
        length.times do
          data, int = decode_var_int(data)
          res << int
        end
        [data, res]
      end

      def decode_net_addr(data, with_time_and_stream = true) # Returns [data_post_consumption, { ... }].
        res = {}
        if with_time_and_stream
          res[:time], res[:stream] = data.unpack("Q>L>")
          data = data[12..-1]
        end
        parts = data.unpack("Q>C16S>")
        res[:services], res[:port] = parts.first, parts.last
        res[:ip] = parts[13...17].map { |c| c.to_i }.join(".")
        [data[26..-1], res]
      end

      # == Other helpers. ==

      def sha512(data)
        @sha512 ||= OpenSSL::Digest::SHA512.new
        @sha512.digest(data)
      end

    end

  end
end
