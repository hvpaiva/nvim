# frozen_string_literal: true

# Loaded into ruby-lsp through RUBYOPT by scripts/nvim-ruby-lsp.
#
# ruby-lsp parses a request's document in its reader thread as the request
# arrives, while the didChange read just before it can still be waiting in the
# worker's queue: the request then runs on the new text with the previous
# tree. Parsing again in the worker, right before each request runs, uses the
# text every earlier change left.
module NvimRubyLspFreshParse
  def process_message(message)
    uri = message.dig(:params, :textDocument, :uri)
    method = message[:method].to_s
    if uri.is_a?(URI::Generic) && !method.start_with?("textDocument/did")
      @global_state.synchronize do
        @store.get(uri).parse!
      rescue RubyLsp::Store::NonExistingDocumentError
        nil
      end
    end
    super
  end
end

TracePoint.new(:class) do |tp|
  next unless tp.self.name == "RubyLsp::Server"

  tp.self.prepend(NvimRubyLspFreshParse)
  tp.disable
end.enable
