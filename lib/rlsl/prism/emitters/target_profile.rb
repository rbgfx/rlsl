# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      TargetProfile = Struct.new(
        :type_map,
        :vector_constructors,
        :matrix_constructors,
        :texture_functions,
        :default_type_name,
        :math_functions,
        :vector_ops,
        keyword_init: true
      ) do
        def initialize(**attributes)
          super(
            type_map: attributes.fetch(:type_map, {}).freeze,
            vector_constructors: attributes.fetch(:vector_constructors, {}).freeze,
            matrix_constructors: attributes.fetch(:matrix_constructors, {}).freeze,
            texture_functions: attributes.fetch(:texture_functions, {}).freeze,
            default_type_name: attributes.fetch(:default_type_name, "float"),
            math_functions: attributes.fetch(:math_functions, {}).freeze,
            vector_ops: attributes.fetch(:vector_ops, {}).freeze
          )
        end
      end
    end
  end
end
