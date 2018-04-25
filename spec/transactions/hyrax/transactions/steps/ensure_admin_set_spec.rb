# frozen_string_literal: true
RSpec.describe Hyrax::Transactions::Steps::EnsureAdminSet do
  subject(:step) { described_class.new }
  let(:work)     { build(:generic_work) }

  describe '#call' do
    context 'without an admin set' do
      it 'is a failure' do
        expect(step.call(work)).to be_failure
      end
    end

    context 'with an admin set' do
      let(:admin_set) { create(:admin_set) }
      let(:work)      { build(:generic_work, admin_set_id: admin_set.id) }

      it 'is a success' do
        expect(step.call(work)).to be_success
      end
    end
  end
end
