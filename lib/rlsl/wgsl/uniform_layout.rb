# frozen_string_literal: true

module RLSL
  module WGSL
    module UniformLayout
      TYPE_INFO = {
        float: [4, 4], int: [4, 4], bool: [4, 4],
        vec2: [8, 8], vec3: [12, 16], vec4: [16, 16]
      }.freeze
      module_function

      def build(fields)
        offset = 0
        result = {}
        fields.each do |name, type|
          size, alignment = TYPE_INFO.fetch(type.to_sym) { raise ArgumentError, "unsupported WGSL uniform type: #{type}" }
          offset = (offset + alignment - 1) / alignment * alignment
          result[name.to_sym] = { offset: offset, type: type.to_sym }
          offset += size
        end
        { fields: result, size: (offset + 15) / 16 * 16 }
      end
    end
  end
end
