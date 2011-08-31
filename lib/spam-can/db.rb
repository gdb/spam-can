require 'em-mongo'

module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

module SpamCan
  module Model
    class ModelCursor
      include LogHelper
      include EMHelper

      def initialize(klass, cursor)
        @klass = klass
        @cursor = cursor
      end

      def each(&blk)
        @cursor.each do |doc|
          if doc.nil?
            log_announce("End of query!")
          else
            blk.call(to_model(doc))
          end
        end
      end

      def first
        # Probably won't close it if it's empty... meh
        lazy_map(@cursor.next_document) { |doc| to_model(doc) }
      end

      def method_missing(name, *args, &blk)
        begin
          @cursor.send(name, *args, &blk)
        rescue NoMethodError
          raise NoMethodError.new("No method to delegete to: #{name.inspect}")
        end
      end

      private

      def to_model(doc)
        if doc.nil?
          nil
        else
          @klass.from_mongo_hash(doc)
        end
      end
    end

    class AbstractModel
      include LogHelper

      @@db = nil
      def self.db
        @@db ||= EM::Mongo::Connection.new.db('spam-can')
      end
      def db; self.class.db; end

      def self.collection(name=nil)
        if name
          @collection_name = name
        else
          db.collection(collection_name)
        end
      end
      def collection; self.class.collection; end

      def self.collection_name
        @collection_name || raise("No collection name set for #{self}")
      end

      def self.ensure_index(*args)
        EM.next_tick { collection.create_index(*args) }
      end

      def self.mapper; @mapper ||= {}; end
      def mapper; self.class.mapper; end

      def self.prop(name, type, opts={})
        name = name.to_s
        mongo_name = (opts[:name] || name).to_s
        mapper[mongo_name] = name
        class_eval do
          define_method(name) do
            value = @values[mongo_name]
            unless value.kind_of?(type) || (opts[:optional] && value.nil?)
              # TODO: turn into a log statement
              log_warn("Invalid #{type.inspect} for #{name}: #{value.inspect}")
            end
            value
          end
          define_method("#{name}=") do |value|
            unless value.kind_of?(type) || (opts[:optional] && value.nil?)
              raise "Invalid #{type.inspect} for #{name}: #{value.inspect}"
            end
            @values[mongo_name] = value
          end
        end
      end
      def self.opt(name, type, opts={})
        prop(name, type, { :optional => true }.merge(opts))
      end

      def self.timestamps!
        @has_timestamps = true
        prop :created_at, Time
        prop :updated_at, Time
      end

      def self.find(*args)
        cursor = collection.find(*args)
        ModelCursor.new(self, cursor)
      end

      def self.find_one(query)
        find(query, :limit => 1).first
      end

      def initialize(opts={})
        @values = {}
        opts.each do |key, value|
          self.send("#{key}=", value)
        end
      end

      def self.from_mongo_hash(opts)
        translated = {}
        opts.each do |key, value|
          key = key.to_s
          if mapper.has_key?(key)
            translated[mapper[key]] = value
          else
            raise("Unrecognized mongo hash key: #{key.inspect}")
          end
        end

        self.new(translated)
      end

      def save
        if @has_timestamps
          # Don't want to trigger uninitialized warning
          @values['created_at'] ||= Time.now
          @values['updated_at'] = Time.now
        end
        begin
          collection.save(@values)
        rescue => e
          log_error("Could not save #{self.inspect}", e)
          raise
        end
      end
    end

    class Email < AbstractModel
      collection 'emails'
      ensure_index :sha1sum, :unique => true

      prop :id, Object, :name => :_id
      prop :sha1sum, BSON::Binary
      prop :contents, String
      prop :spam, Boolean
      prop :training, Boolean
      prop :already_trained, Boolean
      timestamps!

      def extract_message_id
        return unless contents

        if contents =~ /^message-id: (.*)/i
          $1
        else
          nil
        end
      end

      def extract_body
        return unless contents

        if contents =~ /^.*?\r?\n\r?\n(.*)$/m
          $1
        elsif contents !~ /:/
          contents
        else
          nil
        end
      end

      def to_s
        body = (b = extract_body) ? "#{b[0..20]}..." : nil
        attrs = [['spam', spam], ['body', body], ['message_id', extract_message_id]].select { |a,b| !b.nil? }
        "<#{self.class}[#{id}] #{attrs.map {|a,b| "#{a}=#{b.inspect}"}.join(' ')}>"
      end
    end

    class TokenCount < AbstractModel
      collection 'token_counts'
      ensure_index :word, :unique => true

      prop :id, Object, :name => :_id
      prop :word, String
      opt :spam_count, Numeric
      opt :ham_count, Numeric
      opt :probability, Numeric
    end

    # class ProbabilityTable
    #   ensure_index [[:word, 1]], :unique => true

    #   prop :word, String
    #   prop :probability, Numeric
    # end
  end
end
