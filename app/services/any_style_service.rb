class AnyStyleService
    TIMEOUT_SECS = 2.5
    MUTEX = Mutex.new
  
    class << self
      def parser
        @parser ||= AnyStyle::Parser.new
      end
  
      def parse(text)
        Timeout.timeout(TIMEOUT_SECS) do
          MUTEX.synchronize { Array(parser.parse(text)).first || {} }
        end
      rescue Timeout::Error
        {}
      end
    end
  end
  