# frozen_string_literal: true

module RLSL
  class CodeGenerator
    module MathPrelude
      module_function

      def code
        <<~C
          static inline vec2 vec2_new(float x, float y) { return (vec2){x, y}; }
          static inline vec3 vec3_new(float x, float y, float z) { return (vec3){x, y, z}; }
          static inline vec4 vec4_new(float x, float y, float z, float w) { return (vec4){x, y, z, w}; }

          static inline vec2 vec2_add(vec2 a, vec2 b) { return (vec2){a.x + b.x, a.y + b.y}; }
          static inline vec3 vec3_add(vec3 a, vec3 b) { return (vec3){a.x + b.x, a.y + b.y, a.z + b.z}; }

          static inline vec2 vec2_sub(vec2 a, vec2 b) { return (vec2){a.x - b.x, a.y - b.y}; }
          static inline vec3 vec3_sub(vec3 a, vec3 b) { return (vec3){a.x - b.x, a.y - b.y, a.z - b.z}; }

          static inline vec2 vec2_mul(vec2 a, float s) { return (vec2){a.x * s, a.y * s}; }
          static inline vec3 vec3_mul(vec3 a, float s) { return (vec3){a.x * s, a.y * s, a.z * s}; }

          static inline vec2 vec2_div(vec2 a, float s) { return (vec2){a.x / s, a.y / s}; }
          static inline vec3 vec3_div(vec3 a, float s) { return (vec3){a.x / s, a.y / s, a.z / s}; }

          static inline float vec2_dot(vec2 a, vec2 b) { return a.x * b.x + a.y * b.y; }
          static inline float vec3_dot(vec3 a, vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }

          static inline float vec2_length(vec2 v) { return sqrtf(v.x * v.x + v.y * v.y); }
          static inline float vec3_length(vec3 v) { return sqrtf(v.x * v.x + v.y * v.y + v.z * v.z); }

          static inline vec2 vec2_normalize(vec2 v) { float l = vec2_length(v); return l > 0 ? vec2_div(v, l) : v; }
          static inline vec3 vec3_normalize(vec3 v) { float l = vec3_length(v); return l > 0 ? vec3_div(v, l) : v; }

          static inline float fract(float x) { return x - floorf(x); }
          static inline float mix_f(float a, float b, float t) { return a + (b - a) * t; }
          static inline vec3 mix_v3(vec3 a, vec3 b, float t) {
            return (vec3){a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t};
          }

          static inline float clamp_f(float x, float lo, float hi) {
            return x < lo ? lo : (x > hi ? hi : x);
          }

          static inline float smoothstep(float edge0, float edge1, float x) {
            float t = clamp_f((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
            return t * t * (3.0f - 2.0f * t);
          }

          static inline float hash21(vec2 p) {
            float dot = p.x * 12.9898f + p.y * 78.233f;
            return fract(sinf(dot) * 43758.5453f);
          }

          static inline vec2 hash22(vec2 p) {
            float n = sinf(vec2_dot(p, vec2_new(127.1f, 311.7f)));
            return vec2_new(fract(n * 43758.5453f), fract(n * 12345.6789f));
          }

          static inline vec3 reflect(vec3 I, vec3 N) {
            float d = vec3_dot(N, I);
            return vec3_new(I.x - 2.0f * d * N.x, I.y - 2.0f * d * N.y, I.z - 2.0f * d * N.z);
          }

          static inline vec3 refract(vec3 I, vec3 N, float eta) {
            float d = vec3_dot(N, I);
            float k = 1.0f - eta * eta * (1.0f - d * d);
            if (k < 0.0f) {
              return vec3_new(0.0f, 0.0f, 0.0f);
            }

            float s = eta * d + sqrtf(k);
            return vec3_new(eta * I.x - s * N.x, eta * I.y - s * N.y, eta * I.z - s * N.z);
          }
        C
      end
    end
  end
end
