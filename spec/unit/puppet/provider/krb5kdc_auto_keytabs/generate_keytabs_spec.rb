# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:krb5kdc_auto_keytabs).provider(:generate)

describe provider_class do
  let(:test_host) { 'foo.bar.baz' }
  let(:target_dir) { '/tmp/krb5kdc_auto_keytabs.test' }
  let(:test_realm) { 'TEST.REALM' }

  let(:add_principal) do
    <<~ADD_PRINC
      Authenticating as principal puppet_auto/admin@#{test_realm} with password.
      WARNING: no policy specified for host/#{test_host}@#{test_realm}; defaulting to no policy
      Principal "host/#{test_host}@#{test_realm}" created.
    ADD_PRINC
  end

  let(:list_principals) do
    <<~LIST_PRINC
      Authenticating as principal puppet_auto/admin@#{test_realm} with password.
      K/M@#{test_realm}
      host/#{test_host}@#{test_realm}
      nfs/#{test_host}@#{test_realm}
      puppet_auto/admin@#{test_realm}
    LIST_PRINC
  end

  let(:get_principal) do
    <<~GET_PRINC
      Authenticating as principal puppet_auto/admin@#{test_realm} with password.
      Principal: host/#{test_host}@#{test_realm}
      Expiration date: [never]
      Last password change: Thu Jun 09 22:31:01 UTC 2016
      Password expiration date: [none]
      Maximum ticket life: 1 day 00:00:00
      Maximum renewable life: 0 days 00:00:00
      Last modified: Thu Jun 09 22:31:01 UTC 2016 (puppet_auto/admin@#{test_realm})
      Last successful authentication: [never]
      Last failed authentication: [never]
      Failed password attempts: 0
      Number of keys: 2
      Key: vno 1, aes256-cts-hmac-sha1-96, no salt
      Key: vno 1, aes128-cts-hmac-sha1-96, no salt
      MKey: vno 1
      Attributes:
      Policy: [none]
    GET_PRINC
  end

  let(:add_keytab) do
    <<~ADD_KEYTAB
      Authenticating as principal puppet_auto/admin@#{test_realm} with password.
      Entry for principal host/#{test_host} with kvno 1, encryption type aes256-cts-hmac-sha1-96 added to keytab WRFILE:test.keytab.
      Entry for principal host/#{test_host} with kvno 1, encryption type aes128-cts-hmac-sha1-96 added to keytab WRFILE:test.keytab.
    ADD_KEYTAB
  end

  let(:resource) do
    Puppet::Type.type(:krb5kdc_auto_keytabs).new(
      {
        :name => '__default__',
        :realms => test_realm,
        :provider => described_class.name
      },
    )
  end

  let(:provider) { resource.provider }

  before :each do
    Puppet.stubs(:[]).with(:confdir).returns(target_dir)
    Puppet.stubs(:[]).with(:environmentpath).returns(nil)
    Puppet.stubs(:[]).with(:environment).returns('')
    Puppet::Util.stubs(:which).with('kadmin.local').returns('/usr/sbin/kadmin.local')

    provider.stubs(:execute).with(regexp_matches(%r{list_principals})).returns(list_principals)
    provider.stubs(:execute).with(regexp_matches(%r{get_principal})).returns(get_principal)
    provider.stubs(:execute).with(regexp_matches(%r{add_principal})).returns(add_principal)
    provider.stubs(:execute).with(regexp_matches(%r{ktadd})).returns(add_keytab)

    provider.stubs(:introspect_hosts).returns([test_host])
    provider.stubs(:clean_files).returns(true)

    File.stubs(:exist?).with(regexp_matches(%r{\.keytab})).returns(true)
    File.stubs(:exist?).with(regexp_matches(%r{\.kvno})).returns(false)
    File.stubs(:open).with(regexp_matches(%r{\.kvno}), 'w').returns(true)

    FileUtils.stubs(:mkdir_p).returns(true)
    FileUtils.stubs(:chmod).returns(true)
    FileUtils.stubs(:chown).returns(true)
    FileUtils.stubs(:mv).returns(true)
  end

  context 'when generating keytabs' do
    it 'does not have any errors' do
      provider.expects(:execute).with(regexp_matches(%r{ktadd.*.+/#{test_host}@#{test_realm}}))
      provider.expects(:execute).with(regexp_matches(%r{add_principal.*.+/#{test_host}@#{test_realm}})).never

      provider.exists?
      provider.sync_keytabs
    end
  end

  context 'with a matching kvno file' do
    it 'does not have any errors' do
      File.stubs(:exist?).with(regexp_matches(%r{\.kvno})).returns(true)
      File.stubs(:read).with(regexp_matches(%r{\.kvno})).returns("1\n1\n")

      provider.expects(:execute).with(regexp_matches(%r{ktadd.*.+/#{test_host}@#{test_realm}})).never
      provider.expects(:execute).with(regexp_matches(%r{add_principal.*.+/#{test_host}@#{test_realm}})).never

      provider.exists?
      provider.sync_keytabs
    end
  end

  context 'with a non-matching kvno file' do
    it 'does not have any errors' do
      File.stubs(:exist?).with(regexp_matches(%r{\.kvno})).returns(true)
      File.stubs(:read).with(regexp_matches(%r{\.kvno})).returns("1\n2\n")

      provider.expects(:execute).with(regexp_matches(%r{ktadd.*.+/#{test_host}@#{test_realm}})).once
      provider.expects(:execute).with(regexp_matches(%r{add_principal.*.+/#{test_host}@#{test_realm}})).never

      provider.exists?
      provider.sync_keytabs
    end
  end

  context 'when generating keytabs for unknown principals' do
    let(:list_principals) do
      <<~LIST_PRINC
        Authenticating as principal puppet_auto/admin@#{test_realm} with password.
        K/M@#{test_realm}
        puppet_auto/admin@#{test_realm}
      LIST_PRINC
    end

    it 'does not have any errors' do
      provider.expects(:execute).with(regexp_matches(%r{ktadd.*.+/#{test_host}@#{test_realm}})).once
      provider.expects(:execute).with(regexp_matches(%r{add_principal.*.+/#{test_host}@#{test_realm}})).once

      provider.exists?
      provider.sync_keytabs
    end
  end

  context 'when generating keytabs for all known principals' do
    let(:resource) do
      Puppet::Type.type(:krb5kdc_auto_keytabs).new(
        {
          :name => '__default__',
          :all_known => true,
          :realms => test_realm,
          :provider => described_class.name
        },
      )
    end

    it 'does not have any errors' do
      provider.stubs(:introspect_hosts).returns([])

      provider.expects(:execute).with(regexp_matches(%r{ktadd.*.+/#{test_host}@#{test_realm}})).twice
      provider.expects(:execute).with(regexp_matches(%r{add_principal.*.+/#{test_host}@#{test_realm}})).never

      provider.exists?
      provider.sync_keytabs
    end
  end
end
