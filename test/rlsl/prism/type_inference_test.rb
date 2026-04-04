# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTypeInferenceTest < Test::Unit::TestCase
  def setup
    @type_inference = RLSL::Prism::TypeInference.new(
      { texture_size: :vec2 },
      { split_uv: { returns: [:float, :vec2] } }
    )
  end

  test "block propagates inferred types and updates the symbol table" do
    block = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::VarDecl.new(:energy, literal(1.0)),
      RLSL::Prism::IR::Return.new(var(:energy))
    ])

    infer(block)

    assert_equal :float, block.type
    assert_equal :float, block.statements.first.type
    assert_equal :float, block.statements.last.type
    assert_equal :float, @type_inference.lookup(:energy)
  end

  test "register_function adds custom signatures used by infer_func_call" do
    @type_inference.register_function(:helper_color, returns: :vec4)

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

  test "function calls resolve builtin, custom, and receiver fallback return types" do
    builtin = RLSL::Prism::IR::FuncCall.new(:normalize, [var(:direction, :vec3)])
    custom = RLSL::Prism::IR::FuncCall.new(:helper_color, [], nil)
    receiver_fallback = RLSL::Prism::IR::FuncCall.new(:unknown_method, [], var(:surface, :vec4))

    @type_inference.register_function(:helper_color, returns: :vec4)

    infer(builtin)
    infer(custom)
    infer(receiver_fallback)

    assert_equal :vec3, builtin.type
    assert_equal :vec4, custom.type
    assert_equal :vec4, receiver_fallback.type
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
    inference = RLSL::Prism::TypeInference.new(
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

  test "field access and swizzles infer component and vector types" do
    component = RLSL::Prism::IR::FieldAccess.new(var(:color, :vec3), "x")
    uniform_field = RLSL::Prism::IR::FieldAccess.new(var(:u), :texture_size)
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

  test "loops keep nil type and keep loop variables scoped" do
    for_loop = RLSL::Prism::IR::ForLoop.new(
      :i,
      literal(0),
      literal(4),
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::Assignment.new(var(:sum), literal(1.0))
      ])
    )
    while_loop = RLSL::Prism::IR::WhileLoop.new(
      RLSL::Prism::IR::BoolLiteral.new(true),
      RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Break.new])
    )

    infer(for_loop)
    infer(while_loop)

    assert_nil for_loop.type
    assert_nil while_loop.type
    assert_nil @type_inference.lookup(:i)
  end

  test "function definitions infer return types and keep params scoped to the body" do
    definition = RLSL::Prism::IR::FunctionDefinition.new(
      :distance_from_origin,
      [:x, :y],
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::Return.new(
          RLSL::Prism::IR::BinaryOp.new("+", var(:x), var(:y))
        )
      ]),
      param_types: { x: :float, y: :float }
    )

    infer(definition)

    assert_equal :float, definition.return_type
    assert_equal :float, definition.type
    assert_nil @type_inference.lookup(:x)
    assert_nil @type_inference.lookup(:y)
  end

  test "array literals and indexes infer element types" do
    array_literal = RLSL::Prism::IR::ArrayLiteral.new([literal(1.0), literal(2.0)])
    direct_index = RLSL::Prism::IR::ArrayIndex.new(array_literal, literal(0))
    metadata_index = RLSL::Prism::IR::ArrayIndex.new(var(:weights, :buffer), literal(0))

    @type_inference.register(:weights_element_type, :vec3)

    infer(array_literal)
    infer(direct_index)
    infer(metadata_index)

    assert_equal array_type(:float), array_literal.type
    assert_equal :float, direct_index.type
    assert_equal :vec3, metadata_index.type
  end

  test "global declarations register array metadata and scalar types" do
    array_decl = RLSL::Prism::IR::GlobalDecl.new(
      :weights,
      RLSL::Prism::IR::ArrayLiteral.new([literal(1.0), literal(2.0)])
    )
    scalar_decl = RLSL::Prism::IR::GlobalDecl.new(:exposure, literal(0.5))

    infer(array_decl)
    infer(scalar_decl)

    assert_equal array_type(:float), array_decl.type
    assert_equal 2, array_decl.array_size
    assert_equal :float, array_decl.element_type
    assert_equal array_type(:float), @type_inference.lookup(:weights)
    assert_equal :float, @type_inference.lookup(:weights_element_type)
    assert_equal :float, scalar_decl.type
    assert_equal :float, @type_inference.lookup(:exposure)
  end

  test "multiple assignment supports tuple, array, and custom multi-return values" do
    tuple_assignment = RLSL::Prism::IR::MultipleAssignment.new(
      [var(:x), var(:uv)],
      var(:pair, RLSL::Prism::IR::TupleType.new(:float, :vec2))
    )
    array_assignment = RLSL::Prism::IR::MultipleAssignment.new(
      [var(:left), var(:right)],
      RLSL::Prism::IR::ArrayLiteral.new([literal(1.0), literal(2.0)])
    )
    custom_assignment = RLSL::Prism::IR::MultipleAssignment.new(
      [var(:depth), var(:coords)],
      RLSL::Prism::IR::FuncCall.new(:split_uv, [var(:uv, :vec2)])
    )

    infer(tuple_assignment)
    infer(array_assignment)
    infer(custom_assignment)

    assert_equal :float, tuple_assignment.targets[0].type
    assert_equal :vec2, tuple_assignment.targets[1].type
    assert_equal :float, array_assignment.targets[0].type
    assert_equal :float, array_assignment.targets[1].type
    assert_equal :float, custom_assignment.targets[0].type
    assert_equal :vec2, custom_assignment.targets[1].type
    assert_equal :vec2, @type_inference.lookup(:coords)
  end

  test "empty array literals default to float element types" do
    array_literal = RLSL::Prism::IR::ArrayLiteral.new([])

    infer(array_literal)

    assert_equal array_type(:float), array_literal.type
  end

  test "branch-local declarations do not leak outside conditionals" do
    conditional = RLSL::Prism::IR::IfStatement.new(
      RLSL::Prism::IR::BoolLiteral.new(true),
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::VarDecl.new(:branch_value, literal(1.0))
      ])
    )

    infer(conditional)

    assert_nil @type_inference.lookup(:branch_value)
  end

  private

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
