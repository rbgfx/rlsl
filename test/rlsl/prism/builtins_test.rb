# frozen_string_literal: true

require_relative "../../test_helper"

class PrismBuiltinsTest < Test::Unit::TestCase
  test "function? returns true for known functions" do
    assert RLSL::Prism::Builtins.function?(:sin)
    assert RLSL::Prism::Builtins.function?(:vec3)
    assert RLSL::Prism::Builtins.function?(:normalize)
  end

  test "function? returns false for unknown functions" do
    assert_false RLSL::Prism::Builtins.function?(:unknown_func)
  end

  test "single_component_field? identifies x, y, z, w" do
    assert RLSL::Prism::Builtins.single_component_field?("x")
    assert RLSL::Prism::Builtins.single_component_field?("y")
    assert RLSL::Prism::Builtins.single_component_field?("z")
    assert RLSL::Prism::Builtins.single_component_field?("w")
  end

  test "swizzle? identifies multi-component access" do
    assert RLSL::Prism::Builtins.swizzle?("xy")
    assert RLSL::Prism::Builtins.swizzle?("xyz")
    assert RLSL::Prism::Builtins.swizzle?("rgba")
  end

  test "swizzle_type returns correct type" do
    assert_equal :vec2, RLSL::Prism::Builtins.swizzle_type("xy")
    assert_equal :vec3, RLSL::Prism::Builtins.swizzle_type("xyz")
    assert_equal :vec4, RLSL::Prism::Builtins.swizzle_type("xyzw")
  end

  test "binary_op_result_type for arithmetic" do
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("+", :vec3, :vec3)
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :vec3, :float)
    assert_equal :float, RLSL::Prism::Builtins.binary_op_result_type("+", :float, :float)
  end

  test "binary_op_result_type for comparison" do
    assert_equal :bool, RLSL::Prism::Builtins.binary_op_result_type("==", :float, :float)
    assert_equal :bool, RLSL::Prism::Builtins.binary_op_result_type("<", :float, :float)
  end

  test "resolve_return_type for normalize returns same vec type" do
    assert_equal :vec2, RLSL::Prism::Builtins.resolve_return_type(:same, [:vec2])
    assert_equal :vec3, RLSL::Prism::Builtins.resolve_return_type(:same, [:vec3])
  end

  test "resolve_return_type for first arg" do
    assert_equal :vec3, RLSL::Prism::Builtins.resolve_return_type(:first, [:vec3, :float])
  end

  test "resolve_return_type for second arg" do
    assert_equal :vec2, RLSL::Prism::Builtins.resolve_return_type(:second, [:float, :vec2])
  end

  test "resolve_return_type for third arg" do
    assert_equal :vec4, RLSL::Prism::Builtins.resolve_return_type(:third, [:float, :float, :vec4])
  end

  test "resolve_return_type for symbol returns symbol" do
    assert_equal :float, RLSL::Prism::Builtins.resolve_return_type(:float, [])
  end

  test "function_signature returns signature" do
    sig = RLSL::Prism::Builtins.function_signature(:sin)
    assert_equal :float, sig[:returns]
  end

  test "function_signature returns nil for unknown" do
    assert_nil RLSL::Prism::Builtins.function_signature(:unknown_func)
  end

  test "binary_operator? returns true for known operators" do
    assert RLSL::Prism::Builtins.binary_operator?("+")
    assert RLSL::Prism::Builtins.binary_operator?("==")
  end

  test "unary_operator? returns true for known operators" do
    assert RLSL::Prism::Builtins.unary_operator?("-")
    assert RLSL::Prism::Builtins.unary_operator?("!")
  end

  test "vector_type? identifies vectors" do
    assert RLSL::Prism::Builtins.vector_type?(:vec2)
    assert RLSL::Prism::Builtins.vector_type?(:vec3)
    assert RLSL::Prism::Builtins.vector_type?(:vec4)
    assert_false RLSL::Prism::Builtins.vector_type?(:float)
  end

  test "scalar_type? identifies scalars" do
    assert RLSL::Prism::Builtins.scalar_type?(:float)
    assert RLSL::Prism::Builtins.scalar_type?(:int)
    assert_false RLSL::Prism::Builtins.scalar_type?(:vec3)
  end

  test "binary_op_result_type for vector-scalar multiplication" do
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :float, :vec3)
  end

  test "binary_op_result_type for vector-vector multiplication" do
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :vec3, :vec3)
  end

  test "function? returns true for matrix constructors" do
    assert RLSL::Prism::Builtins.function?(:mat2)
    assert RLSL::Prism::Builtins.function?(:mat3)
    assert RLSL::Prism::Builtins.function?(:mat4)
  end

  test "function? returns true for matrix functions" do
    assert RLSL::Prism::Builtins.function?(:inverse)
    assert RLSL::Prism::Builtins.function?(:transpose)
    assert RLSL::Prism::Builtins.function?(:determinant)
  end

  test "function? returns true for texture functions" do
    assert RLSL::Prism::Builtins.function?(:texture2D)
    assert RLSL::Prism::Builtins.function?(:texture)
    assert RLSL::Prism::Builtins.function?(:textureLod)
  end

  test "function_signature for mat4 constructor" do
    sig = RLSL::Prism::Builtins.function_signature(:mat4)
    assert_equal :mat4, sig[:returns]
    assert sig[:variadic]
    assert_equal 1, sig[:min_args]
  end

  test "function_signature for texture2D" do
    sig = RLSL::Prism::Builtins.function_signature(:texture2D)
    assert_equal :vec4, sig[:returns]
    assert_equal %i[sampler2D vec2], sig[:args]
  end

  test "function_signature for inverse" do
    sig = RLSL::Prism::Builtins.function_signature(:inverse)
    assert_equal :same, sig[:returns]
  end

  test "function_signature for determinant" do
    sig = RLSL::Prism::Builtins.function_signature(:determinant)
    assert_equal :float, sig[:returns]
  end

  test "matrix_type? identifies matrices" do
    assert RLSL::Prism::Builtins.matrix_type?(:mat2)
    assert RLSL::Prism::Builtins.matrix_type?(:mat3)
    assert RLSL::Prism::Builtins.matrix_type?(:mat4)
    assert_false RLSL::Prism::Builtins.matrix_type?(:float)
    assert_false RLSL::Prism::Builtins.matrix_type?(:vec4)
  end

  test "matrix_vector_result returns correct vector type" do
    assert_equal :vec2, RLSL::Prism::Builtins.matrix_vector_result(:mat2)
    assert_equal :vec3, RLSL::Prism::Builtins.matrix_vector_result(:mat3)
    assert_equal :vec4, RLSL::Prism::Builtins.matrix_vector_result(:mat4)
  end

  test "binary_op_result_type for matrix-vector multiplication" do
    assert_equal :vec4, RLSL::Prism::Builtins.binary_op_result_type("*", :mat4, :vec4)
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :mat3, :vec3)
    assert_equal :vec2, RLSL::Prism::Builtins.binary_op_result_type("*", :mat2, :vec2)
  end

  test "binary_op_result_type for vector-matrix multiplication" do
    assert_equal :vec4, RLSL::Prism::Builtins.binary_op_result_type("*", :vec4, :mat4)
  end

  test "binary_op_result_type for matrix-matrix multiplication" do
    assert_equal :mat4, RLSL::Prism::Builtins.binary_op_result_type("*", :mat4, :mat4)
    assert_equal :mat3, RLSL::Prism::Builtins.binary_op_result_type("*", :mat3, :mat3)
  end

  test "binary_op_result_type for matrix-scalar multiplication" do
    assert_equal :mat4, RLSL::Prism::Builtins.binary_op_result_type("*", :mat4, :float)
    assert_equal :mat4, RLSL::Prism::Builtins.binary_op_result_type("*", :float, :mat4)
  end
end
