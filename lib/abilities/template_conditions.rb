# frozen_string_literal: true

module Abilities
  module TemplateConditions
    module_function

    def collection(user, ability: nil)
      if user.editor?
        # EDITOR: solo puede ver sus propias plantillas
        Template.where(author_id: user.id, account_id: user.account_id)
      elsif user.viewer?
        # VIEWER: solo ve plantillas compartidas o del account
        templates = Template.where(account_id: user.account_id)

        return templates unless user.account.testing?

        shared_ids =
          TemplateSharing.where({ ability:, account_id: [user.account_id, TemplateSharing::ALL_ID] }.compact)
                         .select(:template_id)

        Template.where(Template.arel_table[:id].in(templates.select(:id).arel.union(:all, shared_ids.arel)))
      else
        # ADMIN u otros: todas las del account
        Template.where(account_id: user.account_id)
      end
    end

    def entity(template, user:, ability: nil)
      return true if template.account_id.blank?
      return true if template.account_id == user.account_id && (user.admin? || template.author_id == user.id)

      return false unless user.account.linked_account_account
      return false if template.template_sharings.blank?

      account_ids = [user.account_id, TemplateSharing::ALL_ID]

      template.template_sharings.any? do |sharing|
        sharing.account_id.in?(account_ids) && (ability.nil? || sharing.ability == 'manage' || sharing.ability == ability)
      end
    end
  end
end
