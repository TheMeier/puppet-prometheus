# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'prometheus server basics' do
  it 'prometheus server via main class works idempotently with no errors' do
    pp = "class{'prometheus': manage_prometheus_server => true }"

    # Run it twice and test for idempotency
    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  # rubocop:disable RSpec/RepeatedExampleGroupBody,RSpec/RepeatedExampleGroupDescription
  describe service('prometheus') do
    it { is_expected.to be_running }
    it { is_expected.to be_enabled }
  end

  describe port(9090) do
    it { is_expected.to be_listening.with('tcp6') }
  end

  it 'prometheus server via server class works idempotently with no errors' do
    pp = 'include prometheus::server'

    # Run it twice and test for idempotency
    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  describe service('prometheus') do
    it { is_expected.to be_running }
    it { is_expected.to be_enabled }
  end

  describe port(9090) do
    it { is_expected.to be_listening.with('tcp6') }
  end

  it 'does not allow admin API' do
    shell('curl -s -XPOST http://127.0.0.1:9090/api/v1/admin/tsdb/snapshot') do |r|
      expect(r.stdout).to match(%r{admin APIs disabled})
      expect(r.exit_code).to eq(0)
    end
  end

  if host_inventory['facter']['os']['name'] == 'Archlinux'
    # Archlinux ships promethes >= 3.0.0
    it 'can access static files' do
      shell('curl -s http://127.0.0.1:9090/query') do |r|
        expect(r.stdout).to match(%r{doctype html})
        expect(r.exit_code).to eq(0)
      end
    end
  else
    it 'can access static files' do
      shell('curl -s http://127.0.0.1:9090/graph') do |r|
        expect(r.stdout).to match(%r{doctype html})
        expect(r.exit_code).to eq(0)
      end
    end
  end

  describe 'updating configuration to enable Admin API' do
    it 'prometheus server via main class works idempotently with no errors' do
      pp = "class{'prometheus': manage_prometheus_server => true, web_enable_admin_api => true }"

      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    it 'allows admin API' do
      shell('curl -s -XPOST http://127.0.0.1:9090/api/v1/admin/tsdb/snapshot') do |r|
        expect(r.stdout).not_to match(%r{admin APIs disabled})
        expect(r.stdout).to match(%r{success})
        expect(r.exit_code).to eq(0)
      end
    end
  end

  describe 'prometheus server with options' do
    it 'is idempotent' do
      pp = "class{'prometheus::server': version => '2.52.0', external_url => '/test'}"
      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe service('prometheus') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe port(9090) do
      it { is_expected.to be_listening.with('tcp6') }
    end
  end

  describe 'prometheus with complex alerts and scrape configs' do
    it 'is idempotent' do
      pp = <<-EOS
    class { 'prometheus::server':
      version => '2.52.0',
      alerts => {
        'groups' => [
          {
            'name' => 'alert.rules',
            'rules' => [
              {
                'alert' => 'InstanceDown',
                'expr'  => 'up == 0',
                'for'   => '5m',
                'labels' => {
                  'severity' => 'page',
                },
                'annotations' => {
                  'summary'     => 'Instance {{ $labels.instance }} down',
                  'description' => '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
                }
              }
            ]
          }
        ]
      },
    }
      EOS
      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe service('prometheus') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe port(9090) do
      it { is_expected.to be_listening.with('tcp6') }
    end
  end

  describe 'prometheus upgrade to latest 2.15.1 works' do
    it 'is idempotent' do
      pp = <<-EOS
    class { 'prometheus::server':
      version => '2.15.1',
      alerts => {
        'groups' => [
          {
            'name' => 'alert.rules',
            'rules' => [
              {
                'alert' => 'InstanceDown',
                'expr'  => 'up == 0',
                'for'   => '5m',
                'labels' => {
                  'severity' => 'page',
                },
                'annotations' => {
                  'summary'     => 'Instance {{ $labels.instance }} down',
                  'description' => '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
                }
              }
            ]
          }
        ]
      },
    }
      EOS
      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe service('prometheus') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe port(9090) do
      it { is_expected.to be_listening.with('tcp6') }
    end
  end
  # rubocop:enable RSpec/RepeatedExampleGroupBody,RSpec/RepeatedExampleGroupDescription
end
