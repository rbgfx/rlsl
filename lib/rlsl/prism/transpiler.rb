# frozen_string_literal: true

require "prism"

require_relative "ir/nodes"
require_relative "source_unit"
require_relative "source_extractor"
require_relative "builtins"
require_relative "ast_visitor"
require_relative "type_inference"
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

      attr_reader :ir, :uniforms, :custom_functions

      def initialize(uniforms = {}, custom_functions = {})
        @uniforms = uniforms
        @custom_functions = custom_functions
        @source_extractor = SourceExtractor.new
        @ir = nil
      end

      def parse_block(block)
        @ir = build_ir(@source_extractor.extract_unit(block))
        infer_ir(@ir)
        @ir
      end

      def parse_source(source)
        @ir = build_ir(source_unit(source))
        infer_ir(@ir)
        @ir
      end

      def emit(target, needs_return: true)
        raise "No IR parsed yet. Call parse_block or parse_source first." unless @ir

        emitter = resolve_emitter(target)
        emitter.emit(@ir, needs_return: needs_return)
      end

      def transpile(block, target)
        parse_block(block)
        emit(target)
      end

      def transpile_source(source, target)
        parse_source(source)
        emit(target)
      end

      def transpile_helpers(block, target, function_signatures = {})
        @ir = build_ir(@source_extractor.extract_unit(block).without_params)
        apply_function_signatures(@ir, function_signatures)
        infer_ir(@ir)

        emit(target, needs_return: false)
      end

      private

      def source_unit(source)
        SourceUnit.from_source(source)
      end

      def build_ir(unit)
        visitor = ASTVisitor.new(uniforms: @uniforms, params: unit.params)
        visitor.parse(unit.body)
      end

      def infer_ir(ir)
        inference = TypeInference.new(@uniforms, @custom_functions)
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

      def extract_block_body(source)
        unit = source_unit(source)
        [unit.params, unit.body]
      end
    end
  end
end
