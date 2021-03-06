#  This extension stores translation stub records for missing translations to
#  the database.
#
#  This is useful if you have a web based translation tool. It will populate
#  the database with untranslated keys as the application is being used. A
#  translator can then go through these and add missing translations.
#
#  Example usage:
#
#     I18n::Backend::Chain.send(:include, I18n::Backend::Sequel::Missing)
#     I18n.backend = I18n::Backend::Chain.new(I18n::Backend::Sequel.new, I18n::Backend::Simple.new)
#
#  Stub records for pluralizations will also be created for each key defined
#  in i18n.plural.keys.
#
#  For example:
#
#    # en.yml
#    en:
#      i18n:
#        plural:
#          keys: [:zero, :one, :other]
#
#    # pl.yml
#    pl:
#      i18n:
#        plural:
#          keys: [:zero, :one, :few, :other]
#
#  It will also persist interpolation keys in Translation#interpolations so
#  translators will be able to review and use them.
module I18n
  module Backend
    class SequelBitemporal
      module Missing
        include Flatten

        RESERVED_KEYS = if defined?(I18n::RESERVED_KEYS)
          I18n::RESERVED_KEYS
        else
          I18n::Backend::Base::RESERVED_KEYS
        end

        def store_default_translations(locale, key, options = {})
          count, scope, separator = options.values_at(:count, :scope, :separator)
          separator ||= I18n.default_separator
          key = normalize_flat_keys(locale, key, scope, separator)

          if Translation.locale(locale).lookup(key).empty?
            interpolations = options.keys - RESERVED_KEYS
            keys = count ? I18n.t('i18n.plural.keys', :locale => locale).map { |k| [key, k].join(FLATTEN_SEPARATOR) } : [key]
            keys.each { |k| store_default_translation(locale, k, interpolations) }
          end
        end

        def store_default_translation(locale, key, interpolations)
          translation = Translation.new :locale => locale.to_s, :key => key
          # We're storing interpolations in the version
          translation.attributes = {:interpolations => interpolations}
          translation.save
        end

        def translate(locale, key, options = {})
          result = catch(:exception) do
            super
          end
          if I18n.const_defined?(:MissingTranslation) && result.is_a?(I18n::MissingTranslation)
            self.store_default_translations(locale, key, options)
            throw(:exception, result)
          end
          result
        rescue I18n::MissingTranslationData => e
          self.store_default_translations(locale, key, options)
          raise e
        end
      end
    end
  end
end
