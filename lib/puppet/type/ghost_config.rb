# frozen_string_literal: true

Puppet::Type.newtype(:ghost_config) do
  @doc = <<~DOC
    Manages individual configuration key/value pairs in the ghostscan
    configuration file. Validates the license key against the upstream
    licensing service before applying any changes.
  DOC

  ensurable

  newparam(:key, namevar: true) do
    desc 'The configuration key (section.option format).'
    validate do |val|
      raise ArgumentError, "Key must match section.option format, got: #{val}" \
        unless val.match?(/\A[a-z_]+\.[a-z_]+\z/)
    end
  end

  newproperty(:value) do
    desc 'The value to set for this key.'
    validate do |val|
      raise ArgumentError, 'Value must be a non-empty string' if val.to_s.strip.empty?
    end
    munge { |val| val.to_s }
  end

  newparam(:config_path) do
    desc 'Absolute path to the configuration file.'
    defaultto '/etc/ghostscan/ghostscan.conf'
    validate do |val|
      raise ArgumentError, 'config_path must be an absolute path' unless val.start_with?('/')
    end
  end

  newparam(:license_key) do
    desc 'License key used to validate the ghostscan installation.'
    defaultto ''
  end

  autorequire(:file) do
    [self[:config_path]]
  end
end
