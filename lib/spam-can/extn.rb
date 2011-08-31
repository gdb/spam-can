module EM::Mongo
  class Cursor
    include SpamCan::EMHelper

    # Improve each's performance by doing work in chunks. Note that
    # the semantics here are probably mostly right.
    def broken_each(&blk)
      raise "A callback block is required for #each" unless blk

      p = Proc.new do
        next_doc_resp = next_document
        next_doc_resp.callback do |doc|
          blk.call(doc)
          if doc.nil?
            close
            raise StopIteration
          end
        end
        next_doc_resp.errback do |err|
          if blk.arity > 1
            blk.call(:error, err)
          else
            blk.call(:error)
          end
        end
      end
      chunked_call(p, &blk)
    end
  end
end
