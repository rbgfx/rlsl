# frozen_string_literal: true

module RLSL
  class CodeGenerator
    class RubyWrapperGenerator
      VECTOR_CONSTRUCTORS = {
        2 => "vec2_new",
        3 => "vec3_new",
        4 => "vec4_new"
      }.freeze

      def initialize(context)
        @context = context
      end

      def generate
        <<~C
          static void render_scanline(uint8_t *pixels, int width, int height, int y, vec2 resolution, Uniforms uniforms) {
            int flipped_y = height - 1 - y;
            for (int x = 0; x < width; x++) {
              vec2 frag_coord = vec2_new((float)x, (float)flipped_y);
              vec3 color = shader_#{@context.name}(frag_coord, resolution, uniforms);
              size_t idx = ((size_t)y * (size_t)width + (size_t)x) * 4;
              // Output as BGRA (macOS native format)
              pixels[idx] = (uint8_t)(clamp_f(color.z, 0.0f, 1.0f) * 255.0f);
              pixels[idx+1] = (uint8_t)(clamp_f(color.y, 0.0f, 1.0f) * 255.0f);
              pixels[idx+2] = (uint8_t)(clamp_f(color.x, 0.0f, 1.0f) * 255.0f);
              pixels[idx+3] = 255;
            }
          }

          typedef struct {
            uint8_t *pixels;
            int width;
            int height;
            vec2 resolution;
            Uniforms uniforms;
          } render_arguments;

          static void *render_without_gvl(void *opaque) {
            render_arguments *arguments = (render_arguments *)opaque;

            #ifdef __APPLE__
            dispatch_apply(arguments->height, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t y) {
              render_scanline(arguments->pixels, arguments->width, arguments->height, (int)y,
                              arguments->resolution, arguments->uniforms);
            });
            #else
            for (int y = 0; y < arguments->height; y++) {
              render_scanline(arguments->pixels, arguments->width, arguments->height, y,
                              arguments->resolution, arguments->uniforms);
            }
            #endif

            return NULL;
          }

          static VALUE shader_#{@context.name}_render(VALUE self, VALUE rb_buffer, VALUE rb_width, VALUE rb_height#{@context.uniform_argument_list}) {
            long long requested_width = NUM2LL(rb_width);
            long long requested_height = NUM2LL(rb_height);
            if (requested_width <= 0 || requested_width > INT_MAX ||
                requested_height <= 0 || requested_height > INT_MAX) {
              rb_raise(rb_eArgError, "width and height must be positive integers no greater than INT_MAX");
            }

            size_t width_size = (size_t)requested_width;
            size_t height_size = (size_t)requested_height;
            if (height_size > SIZE_MAX / width_size || width_size * height_size > SIZE_MAX / 4) {
              rb_raise(rb_eRangeError, "render dimensions overflow the output buffer size");
            }

            size_t required_bytes = width_size * height_size * 4;
            int width = (int)requested_width;
            int height = (int)requested_height;
            vec2 resolution = vec2_new((float)width, (float)height);

            Uniforms uniforms;
            #{uniform_assignments}

            Check_Type(rb_buffer, T_STRING);
            rb_str_modify(rb_buffer);
            if ((size_t)RSTRING_LEN(rb_buffer) < required_bytes) {
              rb_raise(rb_eArgError, "pixel buffer is too small: need %zu bytes, got %ld",
                       required_bytes, RSTRING_LEN(rb_buffer));
            }
            uint8_t *pixels = (uint8_t *)RSTRING_PTR(rb_buffer);

            render_arguments arguments = {pixels, width, height, resolution, uniforms};
            rb_thread_call_without_gvl(render_without_gvl, &arguments, RUBY_UBF_IO, NULL);

            return Qnil;
          }
        C
      end

      private

      def uniform_assignments
        @context.uniform_entries.map do |uniform_name, spec|
          generate_uniform_assignment(uniform_name, spec)
        end.join("\n")
      end

      def generate_uniform_assignment(uniform_name, spec)
        case spec.wrapper_kind
        when :float
          "  uniforms.#{uniform_name} = (float)NUM2DBL(rb_#{uniform_name});"
        when :int
          "  uniforms.#{uniform_name} = NUM2INT(rb_#{uniform_name});"
        when :bool
          "  uniforms.#{uniform_name} = RTEST(rb_#{uniform_name}) ? 1 : 0;"
        when :vector
          generate_vector_uniform_assignment(uniform_name, spec.vector_size)
        else
          raise ArgumentError, "Unsupported compiled uniform type: #{spec.c_type}"
        end
      end

      def generate_vector_uniform_assignment(uniform_name, vector_size)
        constructor = VECTOR_CONSTRUCTORS.fetch(vector_size)
        components = (0...vector_size).map do |index|
          "    (float)NUM2DBL(rb_ary_entry(rb_#{uniform_name}, #{index}))"
        end

        <<~C.strip
          Check_Type(rb_#{uniform_name}, T_ARRAY);
          if (RARRAY_LEN(rb_#{uniform_name}) != #{vector_size}) {
            rb_raise(rb_eArgError, "uniform #{uniform_name} must contain exactly #{vector_size} components");
          }
          uniforms.#{uniform_name} = #{constructor}(
        #{components.join(",\n")}
          );
        C
      end
    end
  end
end
