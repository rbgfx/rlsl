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
    keyword_init: true
  ) do
    def compiled?
      !wrapper_kind.nil?
    end

    def metal_packable?
      !metal_alignment.nil? && !metal_size.nil?
    end
  end

  # C type definitions for the shader system
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
      metal_size: 4
    ),
    vec2: UniformTypeSpec.new(
      c_type: "vec2",
      glsl_type: "vec2",
      wgsl_type: "vec2<f32>",
      msl_type: "float2",
      wrapper_kind: :vector,
      vector_size: 2,
      metal_alignment: 8,
      metal_size: 8
    ),
    vec3: UniformTypeSpec.new(
      c_type: "vec3",
      glsl_type: "vec3",
      wgsl_type: "vec3<f32>",
      msl_type: "float3",
      wrapper_kind: :vector,
      vector_size: 3,
      metal_alignment: 16,
      metal_size: 16
    ),
    vec4: UniformTypeSpec.new(
      c_type: "vec4",
      glsl_type: "vec4",
      wgsl_type: "vec4<f32>",
      msl_type: "float4",
      wrapper_kind: :vector,
      vector_size: 4,
      metal_alignment: 16,
      metal_size: 16
    ),
    int: UniformTypeSpec.new(
      c_type: "int",
      glsl_type: "int",
      wgsl_type: "i32",
      msl_type: "int",
      wrapper_kind: :int,
      metal_alignment: 4,
      metal_size: 4
    ),
    bool: UniformTypeSpec.new(
      c_type: "int",
      glsl_type: "bool",
      wgsl_type: "bool",
      msl_type: "bool",
      wrapper_kind: :bool,
      metal_alignment: 4,
      metal_size: 4
    ),
    mat2: UniformTypeSpec.new(
      c_type: "mat2",
      glsl_type: "mat2",
      wgsl_type: "mat2x2<f32>",
      msl_type: "float2x2"
    ),
    mat3: UniformTypeSpec.new(
      c_type: "mat3",
      glsl_type: "mat3",
      wgsl_type: "mat3x3<f32>",
      msl_type: "float3x3"
    ),
    mat4: UniformTypeSpec.new(
      c_type: "mat4",
      glsl_type: "mat4",
      wgsl_type: "mat4x4<f32>",
      msl_type: "float4x4"
    ),
    sampler2D: UniformTypeSpec.new(
      c_type: "sampler2D",
      glsl_type: "sampler2D",
      wgsl_type: "texture_2d<f32>",
      msl_type: nil
    )
  }.transform_values(&:freeze).freeze

  # Uniform type symbols
  UNIFORM_TYPES = UNIFORM_TYPE_SPECS.keys.freeze

  module UniformTypes
    module_function

    def fetch(type)
      UNIFORM_TYPE_SPECS.fetch(type) do
        raise ArgumentError, "Unsupported uniform type: #{type.inspect}"
      end
    end

    def c_type(type)
      fetch(type).c_type
    end

    def compiled_spec(type)
      spec = fetch(type)
      return spec if spec.compiled?

      raise ArgumentError, "Unsupported compiled uniform type: #{type}"
    end

    def metal_spec(type)
      spec = fetch(type)
      return spec if spec.metal_packable?

      raise ArgumentError, "Unsupported Metal uniform type: #{type}"
    end

    def target_type(type, target)
      spec = fetch(type)
      target_type = spec.public_send(:"#{target}_type")
      return target_type if target_type

      raise ArgumentError, "Unsupported #{target.to_s.upcase} uniform type: #{type}"
    end
  end

  # Type mapping helper
  module TypeMapping
    C_UNIFORM_TYPES = UNIFORM_TYPE_SPECS.transform_values(&:c_type).freeze
  end
end
