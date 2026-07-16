# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/prism_type_inference_helpers"

class PrismTypeInferenceExpressionTest < Test::Unit::TestCase
  include PrismTypeInferenceHelpers

  def setup
    @type_inference = build_type_inference
  end

  test "register_function adds custom signatures used by infer_func_call" do
    @type_inference.register_function(:helper_color, returns: :vec4, params: { strength: :float })

    call = RLSL::Prism::IR::FuncCall.new(:helper_color, [literal(1.0)])
    infer(call)

    assert_equal :vec4, call.type
  end

  test "unary operators preserve operand type or resolve to bool" do
    negated = RLSL::Prism::IR::UnaryOp.new("-", literal(1.0))
    inverted = RLSL::Prism::IR::UnaryOp.new("!", RLSL::Prism::IR::BoolLiteral.new(false))

    infer(negated)
    infer(inverted)

    assert_equal :float, negated.type
    assert_equal :bool, inverted.type
  end

  test "function calls resolve builtin and custom return types and reject unknown functions" do
    builtin = RLSL::Prism::IR::FuncCall.new(:normalize, [var(:direction, :vec3)])
    custom = RLSL::Prism::IR::FuncCall.new(:helper_color, [], nil)
    receiver_fallback = RLSL::Prism::IR::FuncCall.new(:unknown_method, [], var(:surface, :vec4))

    @type_inference.register_function(:helper_color, returns: :vec4)

    infer(builtin)
    infer(custom)
    error = assert_raise(RLSL::Prism::SignatureError) { infer(receiver_fallback) }

    assert_equal :vec3, builtin.type
    assert_equal :vec4, custom.type
    assert_include error.message, "Unknown shader function"
  end

  test "builtin calls validate argument count" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      infer(RLSL::Prism::IR::FuncCall.new(:sin, []))
    end

    assert_include error.message, "Wrong number of arguments for sin"
  end

  test "builtin calls validate argument types" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      infer(RLSL::Prism::IR::FuncCall.new(:sin, [var(:uv, :vec2)]))
    end

    assert_include error.message, "expected float, got vec2"
  end

  test "custom calls validate declared parameter types when present" do
    inference = build_type_inference(
      {},
      { noise: { returns: :float, params: { uv: :vec2, gain: :float } } }
    )

    error = assert_raise(RLSL::Prism::SignatureError) do
      inference.infer(
        RLSL::Prism::IR::FuncCall.new(:noise, [literal(1.0), RLSL::Prism::IR::BoolLiteral.new(true)])
      )
    end

    assert_include error.message, "Invalid argument 1 for noise"
  end

  test "custom calls accept int arithmetic expressions for int parameters" do
    inference = build_type_inference(
      {},
      { get_color: { returns: :vec3, params: { i: :int } } }
    )
    call = RLSL::Prism::IR::FuncCall.new(
      :get_color,
      [
        RLSL::Prism::IR::BinaryOp.new(
          "+",
          literal(1, :int),
          literal(2, :int)
        )
      ]
    )

    inference.infer(call)

    assert_equal :vec3, call.type
    assert_equal :int, call.args.first.type
  end

  test "field access and swizzles infer component and vector types" do
    component = RLSL::Prism::IR::FieldAccess.new(var(:color, :vec3), "x")
    uniform_field = RLSL::Prism::IR::FieldAccess.new(var(:u, :uniforms), :texture_size)
    swizzle = RLSL::Prism::IR::Swizzle.new(var(:position, :vec4), "xyz")

    infer(component)
    infer(uniform_field)
    infer(swizzle)

    assert_equal :float, component.type
    assert_equal :vec2, uniform_field.type
    assert_equal :vec3, swizzle.type
  end

  test "conditionals and parenthesized expressions inherit branch types" do
    if_statement = RLSL::Prism::IR::IfStatement.new(
      RLSL::Prism::IR::BoolLiteral.new(true),
      RLSL::Prism::IR::Block.new([literal(1.0)]),
      RLSL::Prism::IR::Block.new([literal(2.0)])
    )
    ternary = RLSL::Prism::IR::Ternary.new(
      RLSL::Prism::IR::BoolLiteral.new(true),
      var(:a, :vec2),
      var(:b, :vec2)
    )
    parenthesized = RLSL::Prism::IR::Parenthesized.new(var(:wrapped, :mat3))

    infer(if_statement)
    infer(ternary)
    infer(parenthesized)

    assert_equal :float, if_statement.type
    assert_equal :vec2, ternary.type
    assert_equal :mat3, parenthesized.type
  end
end
