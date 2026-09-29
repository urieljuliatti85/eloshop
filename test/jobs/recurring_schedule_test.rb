require "test_helper"
require "fugit" # dependência do Solid Queue, que só a carrega ao subir o scheduler

class RecurringScheduleTest < ActiveSupport::TestCase
  def production_tasks
    raw = ERB.new(Rails.root.join("config/recurring.yml").read).result
    YAML.safe_load(raw, aliases: true).fetch("production")
  end

  test "toda tarefa recorrente aponta para um job que existe, com agenda válida" do
    production_tasks.each do |key, config|
      next unless config["class"]

      assert config["class"].safe_constantize, "#{key}: classe #{config['class']} não existe"
      assert Fugit.parse(config["schedule"]), "#{key}: agenda #{config['schedule'].inspect} inválida"
    end
  end

  test "a reconciliação de pagamentos está agendada" do
    classes = production_tasks.values.filter_map { |config| config["class"] }

    assert_includes classes, "ReconcilePaymentsJob"
  end
end
