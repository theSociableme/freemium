module Freemium
  module Models
    class << self
      def hook(base)
        base.class_eval do
          class_attribute :freemium_modules, :instance_writer => false
          self.freemium_modules ||= []
        end
      end

      alias :included :hook
      alias :extended :hook
    end

    # Creates configuration values for Freemium and for the given module.
    #
    #   Freemium::Models.config(Freemium::Authenticable, :stretches, 10)
    #
    # The line above creates:
    #
    #   1) An accessor called Freemium.stretches, which value is used by default;
    #
    #   2) Some class methods for your model Model.stretches and Model.stretches=
    #      which have higher priority than Freemium.stretches;
    #
    #   3) And an instance method stretches.
    #
    # To add the class methods you need to have a module ClassMethods defined
    # inside the given class.
    #
    def self.config(mod, *accessors) #:nodoc:
      accessors.each do |accessor|
        mod.class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{accessor}
            if defined?(@#{accessor})
              @#{accessor}
            elsif superclass.respond_to?(:#{accessor})
              superclass.#{accessor}
            else
              Freemium.#{accessor}
            end
          end

          def #{accessor}=(value)
            @#{accessor} = value
          end
        METHOD
      end
    end

    # Include the chosen devise modules in your model:
    #
    #   devise :database_authenticatable, :confirmable, :recoverable
    #
    # You can also give any of the devise configuration values in form of a hash,
    # with specific values for this model. Please check your Devise initializer
    # for a complete description on those values.
    #
    def freemium(*modules)
      include Freemium::Models::Subscribable
      options = modules.extract_options!

#       if modules.delete(:authenticatable)
#         ActiveSupport::Deprecation.warn ":authenticatable as module is deprecated. Please give :database_authenticatable instead.", caller
#         modules << :database_authenticatable
#       end
# 
#       if modules.delete(:activatable)
#         ActiveSupport::Deprecation.warn ":activatable as module is deprecated. It's included in your model by default.", caller
#       end
# 
#       if modules.delete(:http_authenticatable)
#         ActiveSupport::Deprecation.warn ":http_authenticatable as module is deprecated and is on by default. Revert by setting :http_authenticatable => false.", caller
#       end

      self.freemium_modules += Freemium::ALL & modules.map(&:to_sym).uniq

      freemium_modules_hook! do
        freemium_modules.each { |m| include Freemium::Models.const_get(m.to_s.classify) }
        options.each { |key, value| send(:"#{key}=", value) }
      end
    end

    # The hook which is called inside devise. So your ORM can include devise
    # compatibility stuff.
    def freemium_modules_hook!
      yield
    end

    # Find an initialize a record setting an error if it can't be found.
    def find_or_initialize_with_error_by(attribute, value, error=:invalid)
      if value.present?
        conditions = { attribute => value }
        record = find(:first, :conditions => conditions)
      end

      unless record
        record = new

        if value.present?
          record.send(:"#{attribute}=", value)
        else
          error = :blank
        end

        record.errors.add(attribute, error)
      end

      record
    end
  end
end

require 'freemium/models/subscribable'