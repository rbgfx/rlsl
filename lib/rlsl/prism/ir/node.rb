# frozen_string_literal: true

module RLSL
  module Prism
    module IR
      class Node
        attr_accessor :type, :location

        def self.visits(method_name)
          define_method(:accept) do |visitor|
            visitor.public_send(method_name, self)
          end
        end

        def accept(_visitor)
          raise NotImplementedError
        end
      end
    end
  end
end
