module Hyrax
  module Actors
    # Responsible for "applying" the various edit and read attributes to the given curation concern.
    # @see Hyrax::AdminSetService for release_date interaction
    class ApplyPermissionTemplateActor < Hyrax::Actors::AbstractActor
      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if create was successful
      def create(env)
        add_edit_users(env)
        next_actor.create(env)
      end

      private

        def add_edit_users(env)
          add_admin_set_participants(env)
          add_collection_participants(env)
        end

        def add_admin_set_participants(env)
          return if env.attributes[:admin_set_id].blank?
          template = Hyrax::PermissionTemplate.find_by!(source_id: env.attributes[:admin_set_id])
          set_curation_concern_access(env, template)
        end

        def add_collection_participants(env)
          return if env.attributes[:collection_id].blank?
          collection_id = env.attributes.delete(:collection_id) # delete collection_id from attributes because works do not have a collection_id property
          template = Hyrax::PermissionTemplate.find_by!(source_id: collection_id)
          set_curation_concern_access(env, template)
        end

        def set_curation_concern_access(env, template)
          env.curation_concern.edit_users += template.agent_ids_for(agent_type: 'user', access: 'manage')
          env.curation_concern.edit_groups += template.agent_ids_for(agent_type: 'group', access: 'manage')
          env.curation_concern.read_users += template.agent_ids_for(agent_type: 'user', access: 'view')
          env.curation_concern.read_groups += template.agent_ids_for(agent_type: 'group', access: 'view')
        end
    end
  end
end
