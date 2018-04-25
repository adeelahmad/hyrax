# frozen_string_literal: true
RSpec.describe Hyrax::Transactions::Steps::EnsurePermissionTemplate do
  subject(:step) { described_class.new }
  let(:work)     { build(:generic_work) }

  describe '#call' do
    context 'without an admin_set' do
      it 'is a failure' do
        expect(step.call(work)).to be_failure
      end
    end

    context 'with an admin_set' do
      let(:work)      { build(:generic_work, admin_set: admin_set) }
      let(:admin_set) { create(:admin_set, with_permission_template: true) }

      it 'is success' do
        expect(step.call(work)).to be_success
      end

      context 'missing PermissionTemplate' do
        let(:admin_set) { create(:admin_set, with_permission_template: false) }

        it 'fails with missing template' do
          expect(step.call(work)).to be_failure
        end
      end
    end
  end
end
