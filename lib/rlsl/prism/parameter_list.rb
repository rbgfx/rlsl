# frozen_string_literal: true

require_relative "errors"

module RLSL
  module Prism
    module ParameterList
      module_function

      def required_names(parameter_container)
        parameters = unwrap(parameter_container)
        return [] unless parameters

        unsupported = children(parameters).reject { |parameter| parameter.is_a?(::Prism::RequiredParameterNode) }
        unless unsupported.empty?
          raise UnsupportedSyntaxError, "Only required positional parameters are supported"
        end

        parameters.requireds.map(&:name)
      end

      def names(parameter_container)
        parameters = unwrap(parameter_container)
        return [] unless parameters

        children(parameters).filter_map { |parameter| parameter.name if parameter.respond_to?(:name) }
      end

      def unwrap(container)
        return container.parameters if container.respond_to?(:parameters)

        container
      end
      private_class_method :unwrap

      def children(parameters)
        if parameters.respond_to?(:compact_child_nodes)
          parameters.compact_child_nodes
        else
          Array(parameters.child_nodes).compact
        end
      end
      private_class_method :children
    end
  end
end
