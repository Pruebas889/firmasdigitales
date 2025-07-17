
# frozen_string_literal: true


class Ability
  include CanCan::Ability


  def initialize(user)
    return unless user.present?


    # === ADMIN ===
    if user.admin?
      can :manage, :all


    # === EDITOR ===
    elsif user.editor?
      # Permisos de plantillas


      can [:read, :create, :update], Template, author_id: user.id, account_id: user.account_id


      can :destroy, Template, author_id: user.id, account_id: user.account_id


      can [:read, :update], Submission, created_by_user_id: user.id


      # Este es el importante 👇 (destruir solo si el envío es suyo)
      can :destroy, Submission, created_by_user_id: user.id


      # Carpetas de plantilla
      can :manage, TemplateFolder, account_id: user.account_id


      # Compartir plantillas
      can :manage, TemplateSharing, template: { account_id: user.account_id }


      # Permisos de envíos
      can :read, Submitter, account_id: user.account_id
     
      # Permiso necesario para que aparezca el botón ENVIAR
      can :create, Submission, account_id: user.account_id


      can :read, Submission, id: Submission.where_user_is_submitter(user).select(:id)
      # Ver y editar sus propias submissions
      can [:read, :update], Submission, created_by_user_id: user.id, account_id: user.account_id


      # Perfil y configuraciones
      can :read, User, account_id: user.account_id
      can :manage, User, id: user.id
      can :manage, EncryptedUserConfig, user_id: user.id
      can :manage, UserConfig, user_id: user.id
      can :manage, AccessToken, user_id: user.id
      can :read, Account, id: user.account_id
      can :access, :reports
      can :read, :report_dashboard


     
    # === VIEWER ===
    elsif user.viewer?
      can :read, Template, Abilities::TemplateConditions.collection(user) do |template|
        Abilities::TemplateConditions.entity(template, user: user, ability: 'read')
      end
      can :read, Submission, account_id: user.account_id
      can :read, Submitter, account_id: user.account_id
      can :read, TemplateFolder, account_id: user.account_id
      can :manage, User, id: user.id
      can :manage, UserConfig, user_id: user.id
      can :access, :reports
      can :read, :report_dashboard
    end
  end
end
