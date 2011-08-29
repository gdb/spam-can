module SpamCan
  module CLIHelper
    def should_exit
      $should_exit
    end

    def log_announce(msg)
      puts msg
    end

    def log_info(msg)
    end

    def input(prompt)
      $stdout.write(prompt)
      $stdout.write(' ')
      $stdout.flush
      line = $stdin.readline
      line.strip
    end

    def handle_signals
      Signal.trap("INT") { schedule_exit }
      Signal.trap("TERM") { schedule_exit }
    end

    def schedule_exit
      if $should_exit
        puts "Second exit request received, shutting down now"
        exit(1)
      else
        puts "First exit request received, gracefully shutting down"
        $should_exit = true
      end
    end

    # Could change this to BSON::Binary
    def binary(str)
      str
    end
  end

  module SpamHelper
    def tokenize(body)
      body = body.to_s
      body = body.gsub(/<--.*?-->/, '') # strip HTML comments
      body = body.split(/[^a-zA-Z0-9'$-]/)
      body = body.select do |token|
        token.length > 0 && token !~ /^\d+$/
      end
      body = body.map { |token| token.downcase }
      body = Set.new(body)
      body
    end
  end
end
