# Changelog

## Unreleased

## 1.0.0 - 2026-04-05

- Breaking: custom translator and emitter integrations now require explicit target `PROFILE` definitions; the old stateful Prism transpiler API and compatibility aliases have been removed.
- Added: the Ruby shader DSL now supports ternary expressions, compound local assignments, and fragment transpilation that can reference globals/constants defined in Ruby helpers.
- Added: `functions` now supports validated signatures via `define`, plus shorthand declarations for `int`, `bool`, `mat2`, `mat3`, `mat4`, and `sampler2D`.
- Changed: compiled shaders and Metal shaders now validate and normalize uniform values at runtime, with clearer errors for missing uniforms and invalid scalar/vector/bool inputs.
- Fixed: integer type inference for custom function calls is preserved, and block source extraction is more reliable for assigned `if` expressions and modifier forms.
- Fixed: native extension builds and target capability errors are more robust, reducing backend-specific build and translation failures.

## 0.1.1 - 2026-01-04

- Make metaco an optional runtime dependency and document its installation.

## 0.1.0 - 2026-01-04

- Initial release.
