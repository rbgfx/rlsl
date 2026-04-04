# frozen_string_literal: true

module RLSL
  module Prism
    module IR
      class GlobalDecl < Node
        attr_reader :name, :initializer
        attr_accessor :is_const, :is_static, :array_size, :element_type

        visits :visit_global_decl

        def initialize(name, initializer, type: nil, is_const: false, is_static: true, array_size: nil, element_type: nil)
          super()
          @name = name
          @initializer = initializer
          @type = type
          @is_const = is_const
          @is_static = is_static
          @array_size = array_size
          @element_type = element_type
        end
      end

      class FunctionDefinition < Node
        attr_reader :name, :params, :body
        attr_accessor :return_type, :param_types

        visits :visit_function_definition

        def initialize(name, params, body, return_type: nil, param_types: {})
          super()
          @name = name
          @params = params
          @body = body
          @return_type = return_type
          @param_types = param_types
          @type = return_type
        end
      end

      class MultipleAssignment < Node
        attr_reader :targets, :value

        visits :visit_multiple_assignment

        def initialize(targets, value)
          super()
          @targets = targets
          @value = value
          @type = nil
        end
      end

      class TupleType
        attr_reader :types

        def initialize(*types)
          @types = types
        end

        def to_sym
          :"tuple_#{types.map(&:to_s).join('_')}"
        end
      end
    end
  end
end
