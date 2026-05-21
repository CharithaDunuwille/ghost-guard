# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ghostscan::service' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) do
        <<~PP
          class ghostscan {
            $manage_service   = true
            $service_enable   = true
            $config_dir       = '/etc/ghostscan'
            $config_file      = 'ghostscan.conf'
            $log_dir          = '/var/log/ghostscan'
            $log_level        = 'info'
            $max_scan_threads = 4
            $scan_interval    = 300
            $retention_days   = 30
            $allowed_owners   = []
            $report_format    = 'json'
            $extra_options    = {}
          }
          include ghostscan
        PP
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_service('ghostscan').with_ensure('running').with_enable(true) }
        it { is_expected.to contain_file('/run/ghostscan').with_ensure('directory') }
        it { is_expected.not_to contain_cron('ghostscan-health-check') }
        it { is_expected.not_to contain_exec('ghostscan-systemd-daemon-reload') }
      end

      context 'with manage => false' do
        let(:params) { { manage: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('ghostscan') }
      end

      context 'with ensure => stopped' do
        let(:params) { { ensure: 'stopped', enable: false } }

        it { is_expected.to contain_service('ghostscan').with_ensure('stopped').with_enable(false) }
      end

      context 'with restart_on_failure => true' do
        let(:params) { { restart_on_failure: true, health_check_interval: 300 } }

        it { is_expected.to contain_cron('ghostscan-health-check').with_user('root') }
      end

      context 'with extra_service_flags set' do
        let(:params) { { extra_service_flags: ['--debug', '--workers=2'] } }

        it { is_expected.to contain_file('/etc/systemd/system/ghostscan.service.d') }
        it { is_expected.to contain_file('/etc/systemd/system/ghostscan.service.d/extra-flags.conf') }
        it { is_expected.to contain_exec('ghostscan-systemd-daemon-reload').with_refreshonly(true) }
      end
    end
  end
end
