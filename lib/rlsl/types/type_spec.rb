# frozen_string_literal: true

module RLSL
  UniformTypeSpec = Struct.new(
    :c_type,
    :glsl_type,
    :wgsl_type,
    :msl_type,
    :wrapper_kind,
    :vector_size,
    :metal_alignment,
    :metal_size,
    :compiled_supported,
    :runtime_supported,
    :function_shorthand,
    keyword_init: true
  ) do
    def compiled?
      compiled_supported
    end

    def metal_packable?
      !metal_alignment.nil? && !metal_size.nil?
    end

    def runtime_supported?
      runtime_supported
    end

    def function_shorthand?
      function_shorthand
    end

    def target_supported?(target)
      !public_send(:"#{target}_type").nil?
    end
  end

  C_TYPES = <<~C
    typedef struct { float x, y; } vec2;
    typedef struct { float x, y, z; } vec3;
    typedef struct { float x, y, z, w; } vec4;
    typedef struct { float m[4]; } mat2;
    typedef struct { float m[9]; } mat3;
    typedef struct { float m[16]; } mat4;
    typedef struct { void* data; int width; int height; } sampler2D;

    #define PI 3.14159265f
    #define TAU 6.28318530f
  C

  UNIFORM_TYPE_SPECS = {
    float: UniformTypeSpec.new(
      c_type: "float",
      glsl_type: "float",
      wgsl_type: "f32",
      msl_type: "float",
      wrapper_kind: :float,
      metal_alignment: 4,
      metal_size: 4,
      compiled_supported: true,
      runtime_supported: true,
      function_shorthand: true
    ),
    vec2: UniformTypeSpec.new(
      c_type: "vec2",
      glsl_type: "vec2",
      wgsl_type: "vec2<f32>",
      msl_type: "float2",
      wrapper_kind: :vector,
      vector_size: 2,
      metal_alignment: 8,
      metal_size: 8,
      compiled_supported: true,
      runtime_supported: true,
      function_shorthand: true
    ),
    vec3: UniformTypeSpec.new(
      c_type: "vec3",
      glsl_type: "vec3",
      wgsl_type: "vec3<f32>",
      msl_type: "float3",
      wrapper_kind: :vector,
      vector_size: 3,
      metal_alignment: 16,
      metal_size: 16,
      compiled_supported: true,
      runtime_supported: true,
      function_shorthand: true
    ),
    vec4: UniformTypeSpec.new(
      c_type: "vec4",
      glsl_type: "vec4",
      wgsl_type: "vec4<f32>",
      msl_type: "float4",
      wrapper_kind: :vector,
      vector_size: 4,
      metal_alignment: 16,
      metal_size: 16,
      compiled_supported: true,
      runtime_supported: true,
      function_shorthand: true
    ),
    int: UniformTypeSpec.new(
      c_type: "int",
      glsl_type: "int",
      wgsl_type: "i32",
      msl_type: "int",
      wrapper_kind: :int,
      metal_alignment: 4,
      metal_size: 4,
      compiled_supported: true,
      runtime_supported: true,
      function_shorthand: true
    ),
    bool: UniformTypeSpec.new(
      c_type: "int",
      glsl_type: "bool",
      wgsl_type: "bool",
      msl_type: "bool",
      wrapper_kind: :bool,
      metal_alignment: 4,
      metal_size: 4,
      compiled_supported: true,
      runtime_supported: true,
      function_shorthand: true
    ),
    mat2: UniformTypeSpec.new(
      c_type: "mat2",
      glsl_type: "mat2",
      wgsl_type: "mat2x2<f32>",
      msl_type: "float2x2",
      compiled_supported: false,
      runtime_supported: false,
      function_shorthand: true
    ),
    mat3: UniformTypeSpec.new(
      c_type: "mat3",
      glsl_type: "mat3",
      wgsl_type: "mat3x3<f32>",
      msl_type: "float3x3",
      compiled_supported: false,
      runtime_supported: false,
      function_shorthand: true
    ),
    mat4: UniformTypeSpec.new(
      c_type: "mat4",
      glsl_type: "mat4",
      wgsl_type: "mat4x4<f32>",
      msl_type: "float4x4",
      compiled_supported: false,
      runtime_supported: false,
      function_shorthand: true
    ),
    sampler2D: UniformTypeSpec.new(
      c_type: "sampler2D",
      glsl_type: "sampler2D",
      wgsl_type: "texture_2d<f32>",
      msl_type: nil,
      compiled_supported: false,
      runtime_supported: false,
      function_shorthand: true
    )
  }.transform_values(&:freeze).freeze

  UNIFORM_TYPES = UNIFORM_TYPE_SPECS.keys.freeze
end
