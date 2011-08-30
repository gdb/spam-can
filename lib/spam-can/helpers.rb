require 'set'

module SpamCan
  class EnumeratorHack
    def initialize(&blk)
      # Ruby 1.8.7's Enumerator doesn't take a block, or might prefer
      # to use that instead.
      @blk = blk
    end

    def next
      @blk.call
    end
  end

  module EMHelper
    def gather(*deferred)
      raise "Cannot take block directly" if block_given?
      outcome = EM::DefaultDeferrable.new

      failed = false
      deferred_count = deferred.length
      success_count = 0
      results = []

      deferred.each_with_index do |d, i|
        d.callback do |res|
          break if failed
          success_count += 1
          results[i] = res

          if success_count == deferred_count
            outcome.succeed(*results)
          end
        end

        d.errback do |err|
          break if failed
          failed = true

          outcome.fail([i, d], err)
        end
      end

      outcome
    end

    # Eventmachine map
    def lazy_map(deferred, &blk)
      outcome = EM::DefaultDeferrable.new

      deferred.callback do |res|
        outcome.succeed(blk.call(res))
      end
      deferred.errback do |err|
        outcome.fail(err)
      end

      outcome
    end

    def iterator_map(iter, &blk)
      EnumeratorHack.new { blk.call(iter.next) }
    end

    def chunked_call(proc, chunk_size=10, &blk)
      begin
        chunk_size.times { proc.call(&blk) }
        EM.next_tick { chunked_call(proc, chunk_size, &blk) }
      rescue StopIteration
        # TODO: maybe should invent own exception here? Not sure.
      end
    end

    def chunked_iterate(iter, chunk_size=10, &blk)
      begin
        chunk_size.times { blk.call(iter.next) }
        EM.next_tick { chunked_iterate(iter, chunk_size, &blk) }
      rescue StopIteration
      end
    end
  end

  module LogHelper
    # Mock out a better implementation
    def log_announce(msg); $stderr.puts(msg); end
    def log_error(msg, e=nil)
      msg = "#{msg}: #{e}" if e
      $stderr.puts(msg)
    end
    def log_info(msg); end
    def log_warn(msg); $stderr.puts(msg); end
    def log_debug(msg); end
  end

  module CLIHelper
    include LogHelper
    @@cnts = {}

    def run
      handle_signals
      EM.next_tick { do_run }
      # Need to figure out how to finish
      EM.run {}
      puts @@cnts.inspect
    end

    def checkpoint(which)
      @@cnts[which] ||= 0
      @@cnts[which] += 1
      exit(0) if should_exit
    end

    def should_exit
      $should_exit
    end

    private

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
