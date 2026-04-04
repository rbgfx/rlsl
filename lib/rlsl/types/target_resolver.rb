# frozen_string_literal: true

module RLSL
  module UniformTypes
    module TargetResolver
      def target_type(type, target)
        spec = fetch(type)
        target_type = spec.public_send(:"#{target}_type")
        return target_type if target_type

        raise ArgumentError, "Unsupported #{target.to_s.upcase} uniform type: #{type}"
      end
    end
  end
end
