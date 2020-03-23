
RSpec.shared_examples 'a namespaceable method' do |normal_expected_result|
  context 'without a namespace' do
    let(:namespace) { nil }

    it 'sends the non namespaced normal_expected_result' do
      basic_action

      expect(socket.recv[0]).to eq_with_telemetry(normal_expected_result)
    end
  end

  context 'with a namespace' do
    let(:namespace) { 'yolo' }

    it 'sends the namespaced normal_expected_result' do
      basic_action

      expect(socket.recv[0]).to eq_with_telemetry("yolo.#{normal_expected_result}")
    end
  end
end