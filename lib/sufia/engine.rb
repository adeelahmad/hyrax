module Sufia
  class Engine < ::Rails::Engine
    engine_name 'sufia'

    # These gems must be required outside of an initializer or it doesn't get loaded.
    require 'breadcrumbs_on_rails'
    require 'jquery-ui-rails'
    require 'flot-rails'
    require 'almond-rails'
    require 'jquery-datatables-rails'
    require 'flipflop'
    require 'qa'

    # Force these models to be added to Legato's registry in development mode
    config.eager_load_paths += %W(
      #{config.root}/app/models/sufia/download.rb
      #{config.root}/app/models/sufia/pageview.rb
    )

    initializer 'requires' do
      require 'hydra/derivatives'
      require 'sufia/name'
      require 'sufia/controller_resource'
    end

    initializer 'routing' do
      require 'sufia/rails/routes'
    end

    initializer 'configure' do
      # Set the path for the flipflop config:
      Flipflop::Engine.config_file = Sufia::Engine.root + "config/features.rb"

      Sufia.config.tap do |c|
        Hydra::Derivatives.ffmpeg_path    = c.ffmpeg_path
        Hydra::Derivatives.temp_file_base = c.temp_file_base
        Hydra::Derivatives.fits_path      = c.fits_path
        Hydra::Derivatives.enable_ffmpeg  = c.enable_ffmpeg
        Hydra::Derivatives.libreoffice_path = c.libreoffice_path

        # TODO: Remove when https://github.com/projecthydra/curation_concerns/pull/848 is merged
        ActiveFedora::Base.translate_uri_to_id = c.translate_uri_to_id
        ActiveFedora::Base.translate_id_to_uri = c.translate_id_to_uri
        ActiveFedora::Noid.config.template = c.noid_template
        ActiveFedora::Noid.config.statefile = c.minter_statefile
      end

      Sufia::CurationConcern.actor_factory = Sufia::ActorFactory
      Sufia::Workflow::WorkflowFactory.workflow_strategy = Sufia::Workflow::WorkflowByAdminSetStrategy
    end

    initializer 'sufia.assets.precompile' do |app|
      app.config.assets.paths << config.root.join('vendor', 'assets', 'fonts')
      app.config.assets.paths << config.root.join('app', 'assets', 'images')
      app.config.assets.paths << config.root.join('app', 'assets', 'images', 'blacklight')
      app.config.assets.paths << config.root.join('app', 'assets', 'images', 'hydra')
      app.config.assets.paths << config.root.join('app', 'assets', 'images', 'site_images')

      app.config.assets.precompile << /fontawesome-webfont\.(?:svg|ttf|woff)$/
      app.config.assets.precompile += %w(*.png *.jpg *.ico *.gif *.svg)
      app.config.assets.precompile += %w(sufia/admin.css)

      Sprockets::ES6.configuration = { 'modules' => 'amd', 'moduleIds' => true }
      # When we upgrade to Sprockets 4, we can ditch sprockets-es6 and config AMD
      # in this way:
      # https://github.com/rails/sprockets/issues/73#issuecomment-139113466
    end
  end
end
