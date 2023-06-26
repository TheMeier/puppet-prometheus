# @summary This module manages prometheus node node_exporter
# @param arch
#  Architecture (amd64 or i386)
# @param bin_dir
#  Directory where binaries are located
# @param collectors
#  deprecated, unused kept for migration scenatrios
#  will be removed in next release
# @param collectors_enable
#  Collectors to enable, addtionally to the defaults
#  https://github.com/prometheus/node_exporter#enabled-by-default
# @param collectors_disable
#  disable collectors which are enabled by default
#  https://github.com/prometheus/node_exporter#enabled-by-default
# @param download_extension
#  Extension for the release binary archive
# @param download_url
#  Complete URL corresponding to the where the release binary archive can be downloaded
# @param download_url_base
#  Base URL for the binary archive
# @param extra_groups
#  Extra groups to add the binary user to
# @param extra_options
#  Extra options added to the startup command
# @param group
#  Group under which the binary is running
# @param init_style
#  Service startup scripts style (e.g. rc, upstart or systemd)
# @param install_method
#  Installation method: url or package (only url is supported currently)
# @param manage_group
#  Whether to create a group for or rely on external code for that
# @param manage_service
#  Should puppet manage the service? (default true)
# @param manage_user
#  Whether to create user or rely on external code for that
# @param os
#  Operating system (linux is the only one supported)
# @param package_ensure
#  If package, then use this for package ensure default 'latest'
# @param package_name
#  The binary package name - not available yet
# @param purge_config_dir
#  Purge config files no longer generated by Puppet
# @param restart_on_change
#  Should puppet restart the service on configuration change? (default true)
# @param service_enable
#  Whether to enable the service from puppet (default true)
# @param service_ensure
#  State ensured for the service (default 'running')
# @param service_name
#  Name of the node exporter service (default 'node_exporter')
# @param user
#  User which runs the service
# @param version
#  The binary release version
# @param env_vars
#  hash with custom environment variables thats passed to the exporter via init script / unit file
# @param env_file_path
#  The path to the file with the environmetn variable that is read from the init script/systemd unit
# @param proxy_server
#  Optional proxy server, with port number if needed. ie: https://example.com:8080
# @param proxy_type
#  Optional proxy server type (none|http|https|ftp)
class prometheus::node_exporter (
  String $download_extension,
  Prometheus::Uri $download_url_base,
  Array[String] $extra_groups,
  String[1] $group,
  String[1] $package_ensure,
  String[1] $package_name,
  String[1] $user,
  String[1] $version,
  Boolean $purge_config_dir                                  = true,
  Boolean $restart_on_change                                 = true,
  Boolean $service_enable                                    = true,
  Stdlib::Ensure::Service $service_ensure                    = 'running',
  String[1] $service_name                                    = 'node_exporter',
  Prometheus::Initstyle $init_style                          = $prometheus::init_style,
  Prometheus::Install $install_method                        = $prometheus::install_method,
  Boolean $manage_group                                      = true,
  Boolean $manage_service                                    = true,
  Boolean $manage_user                                       = true,
  String[1] $os                                              = downcase($facts['kernel']),
  Optional[String[1]] $extra_options                         = undef,
  Optional[Prometheus::Uri] $download_url                    = undef,
  String[1] $arch                                            = $prometheus::real_arch,
  Stdlib::Absolutepath $bin_dir                              = $prometheus::bin_dir,
  Optional[Array[String]] $collectors                        = undef,
  Array[String] $collectors_enable                           = [],
  Array[String] $collectors_disable                          = [],
  Optional[Stdlib::Host] $scrape_host                        = undef,
  Boolean $export_scrape_job                                 = false,
  Stdlib::Port $scrape_port                                  = 9100,
  String[1] $scrape_job_name                                 = 'node',
  Optional[Hash] $scrape_job_labels                          = undef,
  Optional[String[1]] $bin_name                              = undef,
  Hash[String[1], Scalar] $env_vars                          = {},
  Stdlib::Absolutepath $env_file_path                        = $prometheus::env_file_path,
  Optional[String[1]] $proxy_server                          = undef,
  Optional[Enum['none', 'http', 'https', 'ftp']] $proxy_type = undef,

  ### TLS
  Boolean $use_tls_server_config                     = false,
  Optional[Stdlib::Absolutepath] $tls_cert_file      = undef,
  Optional[Stdlib::Absolutepath] $tls_key_file       = undef,
  Optional[Stdlib::Absolutepath] $tls_client_ca_file = undef,
  String[1] $tls_client_auth_type                    = 'RequireAndVerifyClientCert',
  Stdlib::Absolutepath $web_config_file              = '/etc/node_exporter_web-config.yml',
  String[1] $tls_min_version                         = 'TLS12',
  String[1] $tls_max_version                         = 'TLS13',
  Optional[Array[String[1]]] $tls_cipher_suites      = undef,
  Optional[Array[String[1]]] $tls_curve_preferences  = undef,
  Boolean $tls_prefer_server_cipher_suites           = true,

  ### HTTP/2
  Boolean $use_http_server_config = false,
  Boolean $http2                  = true,
  Optional[Hash] $http2_headers   = undef,

  ### Basic Auth
  Optional[Hash] $basic_auth_users = undef,
) inherits prometheus {
  # Prometheus added a 'v' on the realease name at 0.13.0
  if versioncmp ($version, '0.13.0') >= 0 {
    $release = "v${version}"
  } else {
    $release = $version
  }

  $real_download_url = pick($download_url, "${download_url_base}/download/${release}/${package_name}-${version}.${os}-${arch}.${download_extension}")

  if $collectors {
    warning('Use of $collectors parameter is deprecated')
  }

  $notify_service = $restart_on_change ? {
    true    => Service[$service_name],
    default => undef,
  }

  $cmd_collectors_enable = $collectors_enable.map |$collector| {
    "--collector.${collector}"
  }

  $cmd_collectors_disable = $collectors_disable.map |$collector| {
    "--no-collector.${collector}"
  }

  if $use_tls_server_config {
    # if tls is enabled, these values have to be set and cannot be undef anymore
    $valid_tls_cert_file        = assert_type(Stdlib::Absolutepath, $tls_cert_file)
    $valid_tls_key_file         = assert_type(Stdlib::Absolutepath, $tls_key_file)

    $tls_server_config = {
      tls_server_config => {
        cert_file        => $valid_tls_cert_file,
        key_file         => $valid_tls_key_file,
        client_ca_file   => $tls_client_ca_file,
        client_auth_type => $tls_client_auth_type,
        min_version      => $tls_min_version,
        max_version      => $tls_max_version,
        cipher_suites    => $tls_cipher_suites,
        prefer_server_cipher_suites => $tls_prefer_server_cipher_suites,
        curve_preferences           => $tls_curve_preferences,
      },
    }
  } else {
    $tls_server_config = {}
  }

  if $use_http_server_config {
    $http_server_config = {
      http_server_config => {
        http2   => $http2,
        headers => $http2_headers,
      },
    }
  } else {
    $http_server_config = {}
  }

  if $basic_auth_users =~ Undef {
    $basic_auth_config = {}
  } else {
    $basic_auth_config = {
      basic_auth_users => $basic_auth_users,
    }
  }

  $web_config_content = $tls_server_config + $http_server_config + $basic_auth_config

  if empty($web_config_content) {
    file { $web_config_file:
      ensure  => absent,
    }

    $web_config = ''
  } else {
    file { $web_config_file:
      ensure  => file,
      content => $web_config_content.to_yaml,
    }

    if versioncmp($version, '1.5.0') >= 0 {
      $web_config = "--web.config.file=${$web_config_file}"
    } else {
      $web_config = "--web.config=${$web_config_file}"
    }
  }

  $options = [
    $extra_options,
    $cmd_collectors_enable.join(' '),
    $cmd_collectors_disable.join(' '),
    $web_config,
  ].join(' ')

  prometheus::daemon { $service_name:
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    purge              => $purge_config_dir,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
    export_scrape_job  => $export_scrape_job,
    scrape_host        => $scrape_host,
    scrape_port        => $scrape_port,
    scrape_job_name    => $scrape_job_name,
    scrape_job_labels  => $scrape_job_labels,
    bin_name           => $bin_name,
    env_vars           => $env_vars,
    env_file_path      => $env_file_path,
    proxy_server       => $proxy_server,
    proxy_type         => $proxy_type,
  }
}
