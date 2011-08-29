module SpamCan
  module CLIHelper
    def should_exit
      $should_exit
    end

    def log_announce(msg)
      puts msg
    end

    def input(prompt)
      $stdout.write(prompt)
      $stdout.write(' ')
      $stdout.flush
      line = $stdin.readline
      line.strip
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
      body.uniq
      body
    end
  end
end
