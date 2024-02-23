module Avm::Environment
  extend self

  def avm_api
    @avm_api ||= AvmService.new.new_api
  end
end
