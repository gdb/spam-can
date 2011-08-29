require 'mongo_mapper'
require 'mongo'

MongoMapper.config = { 'dev' => { 'database' => 'spam-can' } }
MongoMapper.connect('dev')

module SpamCan
  module Model
    class TrainingEmail
      include MongoMapper::Document
      ensure_index :body, :unique => true

      key :body, BSON::Binary
      key :type, String
      key :trained, Boolean
      timestamps!

      def extract_message_id
        return unless body

        if body.to_s =~ /^message-id: (.*)/
          $1
        else
          raise "No message id for #{body.to_s.inspect}"
        end
      end

      def extract_data
        return unless body

        str = body.to_s
        if str =~ /\n([^:]\n.*)/
          $1
        elsif body !~ /:/
          body
        else
          raise "No body for #{str.to_s.inspect}"
        end
      end

      def to_s
        data = (d = extract_data) ? d[0..20] : nil
        "<#{self.class}[#{id}] type=#{type} data=#{d.inspect} message_id=#{extract_message_id.inspect}"
      end
    end

    class TrainedTable
      include MongoMapper::Document
      ensure_index [[:type, 1], [:word, 1]], :unique => true

      key :word, BSON::Binary
      key :type, String
      key :count, Numeric
    end

    class ProbabilityTable
      include MongoMapper::Document
      ensure_index [[:word, 1]], :unique => true

      key :word, BSON::Binary
      key :probability, Numeric
    end
  end
end
