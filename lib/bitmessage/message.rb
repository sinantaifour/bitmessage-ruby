module Bitmessage
  class Message

    # The "data" parameter has to be encoded as binary.

    MAGIC_VALUE = "\xe9\xbe\xb4\xd9"
    SERVICES_PROVIDED = 1 # Currently hard-coded, as this has no usage in the protocol yet.
    COMMANDS = [:version, :verack, :addr, :inv, :getdata, :msg, :broadcast, :ping, :pong, :alert]
    MAX_PARSED_PAYLOAD_SIZE = 180000000 # Ignore messages with payloads bigger than 180MB, as per the original implementation.

    class << self

      def create(command, opts = {})
        # == Generate the payload depending on the message command. ==
        payload = case command
          when :version
            create_version_payload(
              opts[:dest_ip], opts[:dest_port], opts[:dest_services],
              "0.0.0.0", opts[:src_port], SERVICES_PROVIDED, # The src_ip is ignored by our peers.
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
        payload_length = data[16...20].unpack("L>")
        return [data, nil] if data.bytesize < payload_length + 24 # Data is not complete yet.
        # == We have the full message, consume it and parse it. ==
        header = data[0...24]
        payload = data[24...(24 + payload_length)]
        data = data[(24 + payload_length)..-1] # Consume the message from data.
        if payload_length > MAX_PARSED_PAYLOAD_SIZE # Ignore messages with too big payloads.
          puts "Message payload bigger than MAX_PARSED_PAYLOAD_SIZE (#{MAX_PARSED_PAYLOAD_SIZE}). Ignoring."
          return [data, nil]
        end
        if sha512(payload) != header[20...24] # Incorrect checksum, ignore full message.
          puts "Incorrect message checksum. Ignoring."
          return [data, nil]
        end
        command = header[4...16].gsub(/(\x00)*$/, "").to_sym
        unless COMMANDS.include?(command)
          puts "Incorrect command (#{command}). Ignoring."
          return [data, nil]
        end
        puts "Received command #{command} from #{node.host}:#{node.port}."
        message = send(:"parse_#{command}_payload", payload)
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
        res += encode_var_str("/bitmessage-ruby #{VERSION}/")
        res += encode_var_int_list([STREAM])
        res
      end

      def create_verack_payload
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
        # TODO: continue here.
      end

      def parse_verack_payload(payload)
      end

      def parse_addr_payload(payload)
      end

      def parse_inv_payload(payload)
      end

      def parse_getdata_payload(payload)
      end

      def parse_msg_payload(payload)
      end

      def parse_broadcast_payload(payload)
      end

      def parse_ping_payload(payload)
      end

      def parse_pong_payload(payload)
      end

      def parse_alert_payload(payload)
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
        res += "\x00" * 10 + "\xff" * 2 + ip.split(".").map { |i| [i.to_i].pack("C") }.join("") # Assuming ip contains an IPv4.
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
        res
      end

      def decode_net_addr(data) # Returns [data_post_consumption, { ... }].
        # TODO: write me.
      end

      # == Other helpers. ==

      def sha512(data)
        @sha512 ||= OpenSSL::Digest::SHA512.new
        @sha512.digest(data)
      end

    end

  end
end
