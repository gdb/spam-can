require 'mongo_mapper'
require 'mongo'

MongoMapper.config = { 'dev' => { 'database' => 'spam-can' } }
MongoMapper.connect('dev')

module SpamCan
  module Model
    class TrainingEmail
      include MongoMapper::Document
      ensure_index :body, :unique => true

      key :body, String
      key :type, String
      key :trained, Boolean
      timestamps!

      def extract_message_id
        return unless body

        if body.to_s =~ /^message-id: (.*)/
          $1
        else
          nil
        end
      end

      def extract_data
        return unless body

        str = body.to_s
        if str =~ /^.*?\r\n\r\n(.*)$/m
          $1
        elsif body !~ /:/
          body
        else
          nil
        end
      end

      def to_s
        data = (d = extract_data) ? "#{d[0..20]}..." : nil
        attrs = [['type', type], ['data', data], ['message_id', extract_message_id]].select { |a,b| b }
        "<#{self.class}[#{id}] #{attrs.map {|a,b| "#{a}=#{b.inspect}"}.join(' ')}>"
      end

      def spam?
        case type
        when 'spam', 'testing_spam': true
        when 'good', 'testing_good': false
        else
          raise "Unrecognized type #{type.inspect}"
        end
      end
    end

    class TrainedTable
      include MongoMapper::Document
      ensure_index [[:type, 1], [:word, 1]], :unique => true

      key :word, String
      key :type, String
      key :count, Numeric
    end

    class ProbabilityTable
      include MongoMapper::Document
      ensure_index [[:word, 1]], :unique => true

      key :word, String
      key :probability, Numeric
    end
  end
end
