require 'erb'

require 'remit/common'

module Remit
  module GetPipeline
    class Pipeline
      @parameters = []
      attr_reader :parameters
      
      class << self
        # Create the parameters hash for the subclass.
        def inherited(subclass) #:nodoc:
          subclass.instance_variable_set('@parameters', [])
        end
        
        def parameter(name)
          attr_accessor name
          @parameters << name
        end
        
        def convert_key(key)
          key.to_s.gsub(/_(.)/) { $1.upcase }.to_sym
        end
        
        # Returns a hash of all of the parameters for this request, including
        # those that are inherited.
        def parameters #:nodoc:
          (superclass.respond_to?(:parameters) ? superclass.parameters : []) + @parameters
        end
      end
      
      attr_reader :api
      
      parameter :pipeline_name
      parameter :return_URL
      parameter :caller_key

      def initialize(api, pipeline, options)
        @api = api
        @pipeline = pipeline
        
        options.each do |k,v|
          self.send("#{k}=", v)
        end
      end

      def url
        uri = URI.parse(@pipeline)
        
        query = {}
        self.class.parameters.each do |p|
          val = self.send(p)
          
          # Convert Time values to seconds from Epoch
          val = val.to_i if val.class == Time
          
          query[self.class.convert_key(p.to_s)] = val
        end

        # Remove any unused optional parameters
        query.reject! { |key, value| value.nil? }

        uri.query = SignedQuery.new(@api.pipeline, @api.secret_key, query).to_s
        uri.to_s
      end
    end
    
    class SingleUsePipeline < Pipeline
      parameter :caller_reference
      parameter :payment_reason
      parameter :payment_method
      parameter :transaction_amount
      parameter :recipient_token
    end

    class RecurringUsePipeline < Pipeline
      parameter :caller_reference
      parameter :payment_reason
      parameter :recipient_token
      parameter :transaction_amount
      parameter :validity_start # Time or seconds from Epoch
      parameter :validity_expiry # Time or seconds from Epoch
      parameter :payment_method
      parameter :recurring_period
    end
    
    class PostpaidPipeline < Pipeline
      parameter :caller_reference_sender
      parameter :caller_reference_settlement
      parameter :payment_reason
      parameter :payment_method
      parameter :validity_start # Time or seconds from Epoch
      parameter :validity_expiry # Time or seconds from Epoch
      parameter :credit_limit
      parameter :global_amount_limit
      parameter :usage_limit_type1
      parameter :usage_limit_period1
      parameter :usage_limit_value1
      parameter :usage_limit_type2
      parameter :usage_limit_period2
      parameter :usage_limit_value2
    end
    
    def get_single_use_pipeline(options)
      self.get_pipeline(SingleUsePipeline, options)
    end
    
    def get_recurring_use_pipeline(options)
      self.get_pipeline(RecurringUsePipeline, options)
    end
    
    def get_postpaid_pipeline(options)
      self.get_pipeline(PostpaidPipeline, options)
    end
    
    def get_pipeline(pipeline_subclass, options)
      pipeline = pipeline_subclass.new(self, @pipeline, {
        :caller_key => @access_key
      }.merge(options))
    end
  end
end