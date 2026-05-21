# @summary Manages ghostscan configuration files and directories
#
# This class manages the configuration files, directories, and system
# settings required for the ghostscan service to operate correctly.
#
# @param config_dir
#   Absolute path to the configuration directory.
# @param config_file
#   Name of the primary configuration file.
# @param log_dir
#   Absolute path to the log directory.
# @param log_level
#   Logging verbosity. One of: debug, info, warn, error.
# @param max_scan_threads
#   Number of concurrent scanning threads.
# @param scan_interval
#   Interval in seconds between scheduled scans.
# @param retention_days
#   Number of days to retain scan result files.
# @param allowed_owners
#   List of GitHub owners whose PRs are scanned.
# @param report_format
#   Output format for scan reports. One of: json, yaml, text.
# @param manage_service
#   Whether to manage the ghostscan service resource.
# @param service_enable
#   Whether the service should be enabled at boot.
# @param extra_options
#   Hash of additional key/value options written to config.
#
class ghostscan::config (
  Stdlib::Absolutepath        $config_dir      = $ghostscan::config_dir,
  String[1]                   $config_file     = $ghostscan::config_file,
  Stdlib::Absolutepath        $log_dir         = $ghostscan::log_dir,
  Enum['debug','info','warn','error'] $log_level = $ghostscan::log_level,
  Integer[1, 32]              $max_scan_threads = $ghostscan::max_scan_threads,
  Integer[30, 86400]          $scan_interval   = $ghostscan::scan_interval,
  Integer[1, 365]             $retention_days  = $ghostscan::retention_days,
  Array[String[1]]            $allowed_owners  = $ghostscan::allowed_owners,
  Enum['json','yaml','text']  $report_format   = $ghostscan::report_format,
  Boolean                     $manage_service  = $ghostscan::manage_service,
  Boolean                     $service_enable  = $ghostscan::service_enable,
  Hash[String, Scalar]        $extra_options   = $ghostscan::extra_options,
) {
  assert_private()

  # Directories
  file { $config_dir:
    ensure => directory,
    owner  => 'ghostscan',
    group  => 'ghostscan',
    mode   => '0750',
  }

  file { $log_dir:
    ensure => directory,
    owner  => 'ghostscan',
    group  => 'ghostscan',
    mode   => '0755',
  }

  file { "${config_dir}/scans":
    ensure  => directory,
    owner   => 'ghostscan',
    group   => 'ghostscan',
    mode    => '0750',
    require => File[$config_dir],
  }

  file { "${config_dir}/reports":
    ensure  => directory,
    owner   => 'ghostscan',
    group   => 'ghostscan',
    mode    => '0750',
    require => File[$config_dir],
  }

  # Primary configuration file
  $_owners_joined = join($allowed_owners, ', ')
  $_extra_lines   = $extra_options.reduce('') |$acc, $pair| {
    "${acc}${pair[0]} = ${pair[1]}\n"
  }

  file { "${config_dir}/${config_file}":
    ensure  => file,
    owner   => 'ghostscan',
    group   => 'ghostscan',
    mode    => '0640',
    content => @("END")
      # Managed by Puppet — do not edit manually
      [general]
      log_level      = ${log_level}
      log_dir        = ${log_dir}
      scan_threads   = ${max_scan_threads}
      scan_interval  = ${scan_interval}
      retention_days = ${retention_days}
      report_format  = ${report_format}

      [github]
      allowed_owners = ${_owners_joined}

      [extra]
      ${_extra_lines}
      END
    notify  => $manage_service ? {
      true  => Service['ghostscan'],
      false => undef,
    },
    require => File[$config_dir],
  }

  # Log rotation config
  file { '/etc/logrotate.d/ghostscan':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("END")
      ${log_dir}/*.log {
        daily
        missingok
        rotate ${retention_days}
        compress
        delaycompress
        notifempty
        create 0640 ghostscan ghostscan
      }
      END
  }
}
