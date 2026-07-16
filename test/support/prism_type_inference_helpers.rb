# frozen_string_literal: true

module PrismTypeInferenceHelpers
  DEFAULT_UNIFORMS = { texture_size: :vec2 }.freeze
  DEFAULT_FUNCTIONS = { split_uv: { returns: [:float, :vec2], params: { uv: :vec2 } } }.freeze

  def build_type_inference(uniforms = DEFAULT_UNIFORMS, custom_functions = DEFAULT_FUNCTIONS)
    RLSL::Prism::TypeInference.new(
      Marshal.load(Marshal.dump(uniforms)),
      Marshal.load(Marshal.dump(custom_functions))
    )
  end

  def infer(node)
    @type_inference.infer(node)
  end

  def literal(value, type = nil)
    RLSL::Prism::IR::Literal.new(value, type)
  end

  def var(name, type = nil)
    RLSL::Prism::IR::VarRef.new(name, type)
  end

  def array_type(element_type)
    RLSL::Prism::TypeShapes.array(element_type)
  end
end
