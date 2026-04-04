# frozen_string_literal: true

require "prism"

require_relative "ir/nodes"
require_relative "compilation_unit"
require_relative "source_unit"
require_relative "source_extractor"
require_relative "builtins"
require_relative "ast_visitor"
require_relative "type_inference"
require_relative "target_capability_validator"
require_relative "emitters/base_emitter"
require_relative "emitters/target_emitter"
require_relative "emitters/c_emitter"
require_relative "emitters/msl_emitter"
require_relative "emitters/wgsl_emitter"
require_relative "emitters/glsl_emitter"

module RLSL
  module Prism
    class Transpiler
      TARGETS = {
        c: Emitters::CEmitter,
        msl: Emitters::MSLEmitter,
        wgsl: Emitters::WGSLEmitter,
        glsl: Emitters::GLSLEmitter
      }.freeze

      attr_reader :uniforms, :custom_functions

      def initialize(uniforms = {}, custom_functions = {}, globals: {})
        @uniforms = uniforms
        @custom_functions = custom_functions
        @globals = globals
        @source_extractor = SourceExtractor.new
      end

      def compile_block(block)
        compile_unit(@source_extractor.extract_unit(block))
      end

      def compile_source(source)
        compile_unit(source_unit(source))
      end

      def compile_helpers(block, function_signatures = {})
        compile_unit(
          @source_extractor.extract_unit(block).without_params,
          function_signatures: function_signatures
        )
      end

      def emit(target, compilation:, needs_return: true)
        emitter = resolve_emitter(target)
        validate_target_capabilities!(compilation.ir, target)
        emitter.emit(compilation.ir, needs_return: needs_return)
      end

      def transpile(block, target)
        emit(target, compilation: compile_block(block))
      end

      def transpile_source(source, target)
        emit(target, compilation: compile_source(source))
      end

      def transpile_helpers(block, target, function_signatures = {})
        emit(
          target,
          needs_return: false,
          compilation: compile_helpers(block, function_signatures)
        )
      end

      private

      def source_unit(source)
        SourceUnit.from_source(source)
      end

      def build_ir(unit)
        visitor = ASTVisitor.new(uniforms: @uniforms, params: unit.params)
        visitor.parse(unit.body)
      end

      def compile_unit(unit, function_signatures: nil)
        ir = build_ir(unit)
        apply_function_signatures(ir, function_signatures || {})
        infer_ir(ir)
        CompilationUnit.new(source_unit: unit, ir: ir)
      end

      def infer_ir(ir)
        inference = TypeInference.new(@uniforms, @custom_functions, globals: @globals)
        register_pipeline_symbols(inference)
        inference.infer(ir)
      end

      def register_pipeline_symbols(inference)
        inference.register(:frag_coord, :vec2)
        inference.register(:resolution, :vec2)
      end

      def resolve_emitter(target)
        emitter_class = TARGETS[target.to_sym]
        raise "Unknown target: #{target}" unless emitter_class

        emitter_class.new
      end

      def validate_target_capabilities!(ir, target)
        TargetCapabilityValidator.new.validate!(ir, target)
      end

      def apply_function_signatures(ir, signatures)
        return unless ir.is_a?(IR::Block)

        ir.statements.each do |stmt|
          next unless stmt.is_a?(IR::FunctionDefinition)

          sig = signatures[stmt.name]
          next unless sig

          stmt.return_type = sig[:returns]
          stmt.param_types = sig[:params] || {}
        end
      end
    end
  end
end
