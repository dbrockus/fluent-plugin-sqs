module Fluent

  require 'aws-sdk'

  class SQSInput < Input
    Plugin.register_input('sqs', self)

    def initialize
      super
    end

    config_param :aws_key_id, :string
    config_param :aws_sec_key, :string
    config_param :tag, :string
    config_param :sqs_endpoint, :string, :default => 'sqs.ap-northeast-1.amazonaws.com'
    config_param :sqs_url, :string
    config_param :receive_interval, :time, :default => 1

    def configure(conf)
      super

    end

    def start
      super

      AWS.config(
        :access_key_id => @aws_key_id,
        :secret_access_key => @aws_sec_key,
        :sqs_endpoint => @sqs_endpoint )

      @queue = AWS::SQS.new.queues[@sqs_url]

      @finished = false
      @thread = Thread.new(&method(:run_periodic))
    end

    def shutdown
      super

      @finished = true
      @thread.join
    end

    def run_periodic
      until @finished
        begin
          sleep @receive_interval
          @queue.receive_message do |message|
            record = {}
            record[:body] = message.body.to_s
            record[:handle] = message.handle.to_s
            record[:id] = message.id.to_s
            record[:md5] = message.md5.to_s
            record[:url] = message.queue.url.to_s
            record[:sender_id] = message.sender_id.to_s

            Engine.emit(@tag, Time.now, record)
          end
        rescue
          $log.error "failed to emit or receive", :error => $!.to_s, :error_class => $!.class.to_s
          $log.warn_backtrace $!.backtrace
        end
      end
    end
  end
end