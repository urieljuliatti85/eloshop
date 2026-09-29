class ApplicationJob < ActiveJob::Base
  # Os jobs de aviso por e-mail chamam `deliver_now` e herdam a repetição de
  # falhas transitórias de envio.
  include RetriesTransientDeliveryErrors

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
