module Hyrax
  # Cache page and site-wide analytics
  # This is called by `rake hyrax:stats:import_analytics`
  class AnalyticsImporter
    attr_reader :start_date

    def initialize(start_date, options = {})
      if options[:verbose]
        stdout_logger = Logger.new(STDOUT)
        stdout_logger.level = Logger::INFO
        Rails.logger.extend(ActiveSupport::Logger.broadcast(stdout_logger))
      end

      @logging = options[:logging]
      @delay_secs = options[:delay_secs].to_f
      @number_of_tries = options[:number_of_retries].to_i + 1

      @start_date = start_date
    end

    def import_page_stats(page_token = '0')
      results = analytics_service.page_report(start_date, page_token)
      results[:rows].each do |result|
        create_or_update_page_stat(result)
      end

      return if results[:next_page_token].blank?
      import_page_stats(results[:next_page_token])
    end

    def import_site_stats(page_token = '0')
      results = analytics_service.site_report(start_date, page_token)
      results[:rows].each do |result|
        create_or_update_site_stat(result)
      end

      return if results[:next_page_token].blank?
      import_site_stats(results[:next_page_token])
    end

    # Create or update entries in ResourceStat table for page-level results
    def create_or_update_page_stat(result)
      date = Time.zone.parse(result['date'])
      resource_id = path_to_id(result['pagePath'])
      resource = lookup_resource(resource_id)

      stat = ResourceStat.where(user_id: user_id(resource),
                                resource_id: resource_id,
                                date: date).first_or_initialize(user_id: user_id(resource),
                                                                resource_id: resource_id,
                                                                date: date)

      stat.resource_type = resource.class
      stat.pageviews = result.pageviews.to_i || 0
      stat.sessions = result.sessions.to_i || 0
      stat.visitors = result.visitors.to_i || 0
      stat.save!
    end

    # Create or update entries in ResourceStat table for site-level results
    def create_or_update_site_stat(result)
      date = Time.zone.parse(result['date'])

      # A site record for a given date has no user or resource ids associated with it
      # This allows it to be distinguished from page-level entries
      stat = ResourceStat.where(user_id: nil,
                                resource_id: nil,
                                date: date).first_or_initialize(date: date)

      stat.sessions = result.sessions || 0
      stat.visitors = result.visitors || 0
      stat.save!
    end

    private

      def lookup_resource(resource_id)
        ActiveFedora::Base.find(resource_id)
      end

      def user_id(resource)
        email = resource.depositor
        user = ::User.find_by(email: email)
        user.id
      end

      # Takes a pagePath from an analytics service and returns ID
      # /concern/file_sets/9p290934t?locale=en => 9p290934t
      def path_to_id(page_path)
        page_path.split('/').last.split('?').first
      end

      def analytics_service
        @analytics_service ||= case Hyrax.config.analytics
                               when 'matomo'
                                 Hyrax::Analytics::Matomo
                               when 'google' || true
                                 Hyrax::Analytics::GoogleAnalytics
                               end
      end
  end
end