
RSpec.shared_examples 'a log debuggable method' do |normal_expected_result|
  context 'when in DEBUG mode' do
    before do
      logger.level = Logger::DEBUG
    end

    it 'writes to the log' do
      basic_action

      expect(log.string).to match "Statsd: #{normal_expected_result}"
    end
  end

  context 'when in INFO mode' do
    before do
      logger.level = Logger::INFO
    end

    it 'writes nothing' do
      basic_action

      expect(log.string).to be_empty
    end
  end
end