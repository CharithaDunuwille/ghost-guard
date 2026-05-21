# @summary Manages the ghostscan service and runtime state
#
# Handles service lifecycle — enabling, starting, and performing
# live configuration reloads without a full restart when supported.
#
# @param manage
#   Whether this class actively manages the service resource.
# @param ensure
#   Desired service state: running or stopped.
# @param enable
#   Whether to enable the service at boot.
# @param reload_command
#   Shell command used to signal a live reload.
# @param status_command
#   Command used to check service status outside of systemd.
# @param restart_on_failure
#   Automatically issue a restart if a health-check exec detects a crash.
# @param health_check_interval
#   Frequency in seconds of the health-check cron entry.
# @param pid_file
#   Absolute path to the service PID file.
# @param extra_service_flags
#   Additional flags passed to the service start command via unit override.
#
class ghostscan::service (
  Boolean                      $manage                 = $ghostscan::manage_service,
  Stdlib::Ensure::Service      $ensure                 = 'running',
  Boolean                      $enable                 = $ghostscan::service_enable,
  Optional[String[1]]          $reload_command         = undef,
  Optional[String[1]]          $status_command         = undef,
  Boolean                      $restart_on_failure     = false,
  Integer[60, 3600]            $health_check_interval  = 300,
  Stdlib::Absolutepath         $pid_file               = '/run/ghostscan/ghostscan.pid',
  Array[String[1]]             $extra_service_flags    = [],
) {
  assert_private()

  unless $manage {
    return()
  }

  # Systemd drop-in for extra flags
  unless $extra_service_flags.empty {
    $_flags_str = join($extra_service_flags, ' ')

    file { '/etc/systemd/system/ghostscan.service.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    file { '/etc/systemd/system/ghostscan.service.d/extra-flags.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "[Service]\nExecStart=\nExecStart=/usr/bin/ghostscan ${_flags_str}\n",
      require => File['/etc/systemd/system/ghostscan.service.d'],
      notify  => Exec['ghostscan-systemd-daemon-reload'],
    }

    exec { 'ghostscan-systemd-daemon-reload':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      before      => Service['ghostscan'],
    }
  }

  # PID directory
  file { '/run/ghostscan':
    ensure => directory,
    owner  => 'ghostscan',
    group  => 'ghostscan',
    mode   => '0755',
  }

  # Main service resource
  service { 'ghostscan':
    ensure     => $ensure,
    enable     => $enable,
    hasstatus  => true,
    hasrestart => true,
    require    => File['/run/ghostscan'],
  }

  # Live reload via SIGHUP when reload_command is set
  if $reload_command {
    exec { 'ghostscan-reload':
      command     => $reload_command,
      refreshonly => true,
      require     => Service['ghostscan'],
    }
  }

  # Optional health-check cron — restarts the service if the PID file is
  # missing but the service should be running. Only created when
  # restart_on_failure is true; the command is intentionally conservative.
  if $restart_on_failure and $ensure == 'running' {
    cron { 'ghostscan-health-check':
      ensure  => present,
      user    => 'root',
      minute  => "*/${Integer($health_check_interval / 60)}",
      command => "/bin/bash -c 'test -f ${pid_file} || /bin/systemctl restart ghostscan'",
    }
  }
}
