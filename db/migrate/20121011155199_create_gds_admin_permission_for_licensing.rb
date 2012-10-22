class CreateGdsAdminPermissionForLicensing < ActiveRecord::Migration
  def up
  	licence_application.supported_permissions.find_or_create_by_name("GDSadministrator")    
  end

  def down
  end

  class ::Doorkeeper::Application < ActiveRecord::Base
    has_many :permissions, :dependent => :destroy
    has_many :supported_permissions, :dependent => :destroy

    def self.default_permission_strings
      ["signin"]
    end

    def supported_permission_strings
      self.class.default_permission_strings + supported_permissions.order(:name).map(&:name)
    end

    def url_without_path
      parsed_url = URI.parse(redirect_uri)
      url_without_path = "#{parsed_url.scheme}://#{parsed_url.host}:#{parsed_url.port}"
    end
  end

    def licence_application()
      Doorkeeper::Application.where(name: 'Licensify').first
    end
end