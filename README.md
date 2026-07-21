# RLSL

Ruby Like Shading Language - A Ruby DSL for writing shaders that transpile to multiple GPU shader languages.

## Features

- Write shaders using Ruby syntax
- Transpile to multiple targets:
  - GLSL (OpenGL Shading Language)
  - WGSL (WebGPU Shading Language)
  - MSL (Metal Shading Language)
  - C (for CPU-based rendering)
- Type inference for shader variables
- Support for common shader operations (vec2, vec3, vec4, etc.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rlsl'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rlsl
```

## Usage

### Basic Example

```ruby
require 'rlsl'

# Generate GLSL shader
glsl_code = RLSL.to_glsl(:my_shader) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    # Normalize coordinates
    uv = frag_coord / resolution

    # Create color based on position and time
    r = sin(u.time + uv.x * 6.28) * 0.5 + 0.5
    g = sin(u.time + uv.y * 6.28) * 0.5 + 0.5
    b = sin(u.time) * 0.5 + 0.5

    vec3(r, g, b)
  end
end

puts glsl_code
```

### Generate WGSL (WebGPU)

```ruby
wgsl_code = RLSL.to_wgsl(:my_shader) do
  uniforms do
    float :time
    vec2 :mouse
  end

  fragment do |frag_coord, resolution, u|
    uv = frag_coord / resolution.y
    color = vec3(uv.x, uv.y, sin(u.time) * 0.5 + 0.5)
    color
  end
end
```

### Generate MSL (Metal)

```ruby
msl_code = RLSL.to_msl(:my_shader) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    vec3(1.0, 0.0, 0.0)
  end
end
```

`RLSL.to_glsl`, `RLSL.to_wgsl`, and `RLSL.to_msl` return source strings. `RLSL.define` compiles the C target for CPU rendering, while `RLSL.define_metal` returns an `RLSL::MSL::Shader` for optional Metal execution.

### Using Helper Functions

```ruby
RLSL.to_glsl(:complex_shader) do
  uniforms do
    float :time
  end

  functions do
    define :noise, returns: :float, params: { p: :vec2 }
    define :get_color, returns: :vec3, params: { uv: :vec2, t: :float }
  end

  helpers(:ruby) do
    def noise(p)
      sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453
    end

    def get_color(uv, t)
      vec3(uv.x, uv.y, sin(t) * 0.5 + 0.5)
    end
  end

  fragment do |frag_coord, resolution, u|
    uv = frag_coord / resolution
    get_color(uv, u.time)
  end
end
```

Every Ruby helper function needs a complete declaration in `functions`; parameter names and order must match the Ruby method definition. This prevents unknown parameters from silently becoming floats.

### Fragment Parameters and Explicit Source

Fragment parameters are positional. The first parameter is the fragment coordinate (`vec2`), the second is the resolution (`vec2`), and the third is the uniform object. Their Ruby names may be changed; generated target code uses the canonical names `frag_coord`, `resolution`, and `u`.

Ruby-mode blocks are captured from their source file when `fragment` or `helpers` is declared. They must come from a readable file, and multiple shader blocks must not start on the same source line. Code created by `eval`, `ruby -e`, or some REPLs has no readable source file. Once declared, later edits to the file do not change the captured shader source.

For generated code and REPL use, provide the Ruby source explicitly with `fragment_source` or `helpers_source`:

```ruby
builder = RLSL::ShaderBuilder.new(:generated_shader)
builder.fragment_source <<~RUBY
  |coordinate, size, uniforms|
  uv = coordinate / size
  vec3(uv.x, uv.y, uniforms.time)
RUBY
```

A block with parameters is automatically treated as Ruby shader code. A no-argument block defaults to legacy C-source mode; use `fragment(:ruby) { vec3(1.0, 0.0, 0.0) }` to select Ruby mode explicitly. Raw helper or fragment source can be selected with `helpers(:c)` and `fragment(:c)`.

WGSL generation supports Ruby shader source only. Legacy C snippets can still be translated to C, GLSL, and MSL, but `to_wgsl` rejects them because C declarations and function syntax cannot be converted into valid WGSL by identifier rewriting alone.

Use `builder.uniform_types` to inspect declared uniform types. The block form of `uniforms` remains the declaration API.

Uniform names must be ASCII identifiers and may not use the RLSL-reserved names `resolution`, `frag_coord`, or `u`. Duplicate uniform declarations are rejected. The generated GLSL uniform block uses `std140` at binding 1.

### Texture Resources

`sampler2D` uniforms are source-generation resources for GLSL, WGSL, and MSL. Use `texture`, `texture2D`, or `textureLod` in Ruby shader code. They are not fields in the uniform buffer:

- GLSL reserves binding 0 for output and binding 1 for the uniform block; textures begin at binding 2.
- WGSL uses group 0 bindings 0 and 1 for the uniform buffer and output. Each texture/sampler pair then uses bindings 2/3, 4/5, and so on.
- MSL uses texture 0 for output, texture 1 onward for sampled textures, and buffer 0 for uniforms. The generated shader uses an internal linear sampler.

The C renderer and the current `metaco` runtime path do not bind `sampler2D` resources; attempts to use texture functions on C are rejected with a target-capability error. Texture-enabled source can still be emitted with `to_glsl`, `to_wgsl`, or `to_msl` and bound by the host application.

## Supported Types

- `bool` - Boolean (conditional logic)
- `int` - Integer (loop counters, array indices)
- `float` - Scalar floating point
- `vec2` - 2D vector
- `vec3` - 3D vector
- `vec4` - 4D vector
- `mat4` - 4x4 matrix (MVP transformations)
- `mat3` - 3x3 matrix (normal transformations)
- `mat2` - 2x2 matrix (2D texture coordinate transformations)
- `sampler2D` - 2D texture sampler

Scalar and vector uniforms (`bool`, `int`, `float`, and `vec2` through `vec4`) are supported by the CPU and Metal runtime packers. Matrix and sampler uniforms are source-generation only.

## Built-in Functions

RLSL supports common shader functions:

- Math: `sin`, `cos`, `tan`, `sqrt`, `pow`, `exp`, `log`, `abs`, `floor`, `ceil`
- Vector: `normalize`, `length`, `dot`, `cross`, `reflect`, `refract`
- Interpolation: `mix`, `clamp`, `smoothstep`
- Other: `fract`, `min`, `max`

## Constants

- `PI` - 3.14159265358979323846
- `TAU` - 6.28318530717958647692

Ruby-style `Math::PI` and `Math::TAU` are accepted as aliases in shader source.

## Requirements

- Ruby >= 3.1.0
- [Prism](https://github.com/ruby/prism) >= 1.0.0 (for Ruby parsing)
- A working Ruby C-extension toolchain for `RLSL.define` (`make` is selected from Ruby's `RbConfig`)

The test matrix covers supported Ruby releases on Ubuntu, macOS, and Windows, and runs a dedicated compatibility job against the declared Prism 1.0.0 lower bound. Metal runtime execution is macOS-only. GLSL, WGSL, and MSL source generation is platform-independent.

### Optional: Metal Shader Execution (macOS only)

To run Metal shaders natively, install the [metaco](https://github.com/ydah/metaco) gem separately:

```bash
$ gem install metaco
```

Or add to your Gemfile:

```ruby
gem "metaco", platforms: :ruby, install_if: -> { RUBY_PLATFORM.include?("darwin") }
```

MSL code generation (`RLSL.to_msl` or `RLSL.define_metal`) works without metaco. The gem is only required when calling `render_metal` at runtime.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then run `rake verify` for lint and tests.

```bash
$ bundle install
$ rake verify
```

For a quick local coverage summary, run `COVERAGE=1 rake test`. Set `COVERAGE_MIN=85` to enforce a minimum percentage. Target compiler integration tests use `glslangValidator`, Naga's `naga` CLI, and `xcrun metal` when those tools are installed; CI requires the GLSL and WGSL validators.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
