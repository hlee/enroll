require 'rails_helper'

RSpec.describe UserMailer do
  describe 'generic_consumer_welcome' do
    let(:hbx_id) { rand(10000 )}
    let(:email){UserMailer.generic_consumer_welcome('john', hbx_id, 'john@dc.gov')}

    it 'should not allow a reply' do
    	expect(email.from).to match(["no-reply@individual.dchealthlink.com"])
    end

    it 'should deliver to john' do
    	expect(email.to).to match(['john@dc.gov'])
      expect(email.body).to match(/Dear john/)
    end

    it 'should have subject of DC HealthLink' do
      expect(email.subject).to match(/DC HealthLink/)
    end

    it 'should have body text' do
      expect(email.body).to match(/DC Health Link is strongly committed/)
      expect(email.body).to match(/Your Account/)
      expect(email.body).to match(/Questions\?  Call DC Health Link Customer Service/)
    end
  end
end
