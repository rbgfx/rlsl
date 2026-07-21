# frozen_string_literal: true

require_relative "../../test_helper"

class BaseEmitterTest < Test::Unit::TestCase
  def setup
    @emitter = RLSL::Prism::Emitters::CEmitter.new
  end

  test "PRECEDENCE constant defined" do
    prec = RLSL::Prism::Emitters::BaseEmitter::PRECEDENCE
    assert prec.key?("||")
    assert prec.key?("&&")
    assert prec.key?("+")
    assert prec.key?("*")
  end

  test "emit_block with empty statements" do
    block = RLSL::Prism::IR::Block.new([])
    result = @emitter.send(:emit_block, block)
    assert_equal "", result
  end

  test "emit_block with needs_return" do
    block = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ])
    result = @emitter.send(:emit_block, block, needs_return: true)
    assert result.include?("return 1.0f")
  end

  test "emit_function_definition with params" do
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(RLSL::Prism::IR::VarRef.new(:x))
    ])
    func = RLSL::Prism::IR::FunctionDefinition.new(
      :helper,
      [:x, :y],
      body,
      return_type: :float,
      param_types: { x: :float, y: :float }
    )

    result = @emitter.emit(func)
    assert result.include?("static inline float helper")
    assert result.include?("float x")
    assert result.include?("float y")
  end

  test "emit_function_definition with array return type" do
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(
        RLSL::Prism::IR::ArrayLiteral.new([
          RLSL::Prism::IR::Literal.new(1.0, :float),
          RLSL::Prism::IR::Literal.new(2.0, :float)
        ])
      )
    ])
    func = RLSL::Prism::IR::FunctionDefinition.new(
      :multi_return,
      [],
      body,
      return_type: [:float, :float]
    )

    result = @emitter.emit(func)
    assert result.include?("typedef struct")
    assert result.include?("multi_return_result")
  end

  test "emit_global_decl with array" do
    elements = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float),
      RLSL::Prism::IR::Literal.new(3.0, :float)
    ]
    init = RLSL::Prism::IR::ArrayLiteral.new(elements)
    decl = RLSL::Prism::IR::GlobalDecl.new(
      :MY_ARRAY,
      init,
      type: nil,
      is_const: true,
      is_static: true,
      array_size: 3,
      element_type: :float
    )

    result = @emitter.emit(decl)
    assert result.include?("static const float MY_ARRAY[3]")
  end

  test "emit_global_decl with scalar" do
    init = RLSL::Prism::IR::Literal.new(42.0, :float)
    decl = RLSL::Prism::IR::GlobalDecl.new(
      :MY_CONST,
      init,
      type: :float,
      is_const: true,
      is_static: true
    )

    result = @emitter.emit(decl)
    assert result.include?("static const float MY_CONST")
  end

  test "emit static vector global with an aggregate initializer" do
    init = RLSL::Prism::IR::FuncCall.new(
      :vec3,
      [
        RLSL::Prism::IR::Literal.new(1.0, :float),
        RLSL::Prism::IR::Literal.new(0.0, :float),
        RLSL::Prism::IR::Literal.new(0.0, :float)
      ],
      nil,
      :vec3
    )
    decl = RLSL::Prism::IR::GlobalDecl.new(:direction, init, type: :vec3, is_static: true)

    assert_equal "static vec3 direction = {1.0f, 0.0f, 0.0f}", @emitter.emit(decl)
  end

  test "emit_multiple_assignment with func call" do
    func_call = RLSL::Prism::IR::FuncCall.new(:get_pair, [])
    targets = [
      RLSL::Prism::IR::VarRef.new(:a, :float),
      RLSL::Prism::IR::VarRef.new(:b, :float)
    ]
    assign = RLSL::Prism::IR::MultipleAssignment.new(targets, func_call)

    result = @emitter.emit(assign)
    assert result.include?("get_pair_result")
    assert result.include?("float a")
    assert result.include?("float b")
  end

  test "emit_multiple_assignment with array" do
    array = RLSL::Prism::IR::VarRef.new(:arr)
    targets = [
      RLSL::Prism::IR::VarRef.new(:x, :float),
      RLSL::Prism::IR::VarRef.new(:y, :float)
    ]
    assign = RLSL::Prism::IR::MultipleAssignment.new(targets, array)

    result = @emitter.emit(assign)
    assert result.include?("float x = arr[0]")
    assert result.include?("float y = arr[1]")
  end

  test "emit_array_literal" do
    elements = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float)
    ]
    array = RLSL::Prism::IR::ArrayLiteral.new(elements)

    result = @emitter.emit(array)
    assert_equal "{1.0f, 2.0f}", result
  end

  test "emit_vector_math_call through profile resolver" do
    call = RLSL::Prism::IR::FuncCall.new(:normalize, [RLSL::Prism::IR::VarRef.new(:dir, :vec3)])

    result = @emitter.emit(call)

    assert_equal "vec3_normalize(dir)", result
  end

  test "emit_vector_binary_op through profile resolver" do
    binary = RLSL::Prism::IR::BinaryOp.new(
      "+",
      RLSL::Prism::IR::VarRef.new(:left, :vec2),
      RLSL::Prism::IR::VarRef.new(:right, :vec2)
    )

    result = @emitter.emit(binary)

    assert_equal "vec2_add(left, right)", result
  end

  test "emit_array_index with literal index" do
    array = RLSL::Prism::IR::VarRef.new(:arr)
    index = RLSL::Prism::IR::Literal.new(0, :int)
    access = RLSL::Prism::IR::ArrayIndex.new(array, index)

    result = @emitter.emit(access)
    assert_equal "arr[0]", result
  end

  test "emit_array_index with variable index" do
    array = RLSL::Prism::IR::VarRef.new(:arr)
    index = RLSL::Prism::IR::VarRef.new(:i)
    access = RLSL::Prism::IR::ArrayIndex.new(array, index)

    result = @emitter.emit(access)
    assert_equal "arr[i]", result
  end

  test "emit_terminal_statement for if statement" do
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ])
    else_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ])
    if_stmt = RLSL::Prism::IR::IfStatement.new(condition, then_branch, else_branch)

    result = @emitter.send(:emit_terminal_statement, if_stmt)
    assert result.include?("if (1)")
    assert result.include?("return 1.0f")
    assert result.include?("return 0.0f")
  end

  test "emit_terminal_statement for global decl" do
    init = RLSL::Prism::IR::Literal.new(1.0, :float)
    decl = RLSL::Prism::IR::GlobalDecl.new(:X, init)

    result = @emitter.send(:emit_terminal_statement, decl)
    assert result.include?("X")
  end

  test "emit_for_static_init with vec3" do
    vec_call = RLSL::Prism::IR::FuncCall.new(:vec3, [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ])

    result = @emitter.send(:emit_for_static_init, vec_call, true)
    assert_equal "{1.0f, 0.0f, 0.0f}", result
  end

  test "emit_for_static_init with regular node" do
    lit = RLSL::Prism::IR::Literal.new(1.0, :float)

    result = @emitter.send(:emit_for_static_init, lit, true)
    assert_equal "1.0f", result
  end

  test "emit_elsif chain" do
    condition1 = RLSL::Prism::IR::BinaryOp.new(">", RLSL::Prism::IR::VarRef.new(:x), RLSL::Prism::IR::Literal.new(0.0))
    condition2 = RLSL::Prism::IR::BinaryOp.new("<", RLSL::Prism::IR::VarRef.new(:x), RLSL::Prism::IR::Literal.new(0.0))

    then1 = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(1.0))])
    then2 = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(-1.0))])
    else_final = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(0.0))])

    elsif_stmt = RLSL::Prism::IR::IfStatement.new(condition2, then2, else_final)
    if_stmt = RLSL::Prism::IR::IfStatement.new(condition1, then1, elsif_stmt)

    result = @emitter.emit(if_stmt)
    assert result.include?("if (x > 0.0f)")
    assert result.include?("else if (x < 0.0f)")
    assert result.include?("else {")
  end

  test "format_number with integer" do
    result = @emitter.send(:format_number, 1)
    assert_equal "1", result
  end

  test "format_number with float" do
    result = @emitter.send(:format_number, 1.5)
    assert_equal "1.5f", result
  end

  test "indent at different levels" do
    assert_equal "", @emitter.send(:indent)

    @emitter.instance_variable_set(:@indent_level, 1)
    assert_equal "  ", @emitter.send(:indent)

    @emitter.instance_variable_set(:@indent_level, 2)
    assert_equal "    ", @emitter.send(:indent)
  end

  test "current_return_struct_name default" do
    result = @emitter.send(:current_return_struct_name)
    assert_equal "result", result
  end

  test "function_name returns string" do
    result = @emitter.send(:function_name, :my_func)
    assert_equal "my_func", result
  end
end
