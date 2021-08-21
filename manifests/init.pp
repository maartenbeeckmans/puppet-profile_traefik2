#
class profile_traefik2 (
  Hash                 $entrypoints,
  String               $consul_datacenter,
  Stdlib::Absolutepath $consul_root_ca_file,
  Stdlib::Absolutepath $consul_cert_file,
  Stdlib::Absolutepath $consul_key_file,
  Hash                 $dynamic_config,
  String               $version,
  Boolean              $expose_api,
  Boolean              $expose_metrics,
  Boolean              $manage_firewall_entry,
  String               $sd_service_name,
  Array                $sd_service_tags,
  Integer              $traefik_api_port,
  Array                $service_domain_names,
  String               $consul_prefix,
  Hash                 $services,
  Boolean              $enable_letsencrypt,
  Optional[String]     $letsencrypt_email,
  Optional[String]     $letsencrypt_challenge_entrypoint,
  Boolean              $manage_sd_service                = lookup('manage_sd_service', Boolean, first, true),
) {
  openssl::certificate::x509 { $facts['networking']['fqdn']:
    country      => 'BE',
    organization => $facts['networking']['domain'],
    commonname   => $facts['networking']['fqdn'],
    altnames     => $service_domain_names,
  }

  if $enable_letsencrypt {
    $_certificates_resolvers = {
      certificatesResolvers => {
        le => {
          acme => {
            email => $letsencrypt_email,
            storage => '/var/lib/traefik2/letsencrypt.json',
            httpChallenge => {
              entryPoint => $letsencrypt_challenge_entrypoint,
            }
          }
        }
      }
    }
  } else {
    $_certificates_resolvers = {}
  }

  $_static_config = {
    entryPoints => $entrypoints,
    metrics     => {
      prometheus => {
        addEntryPointsLabels => true,
        addServicesLabels    => true,
      }
    },
    ping        => {},
    log         => {
      level   => 'INFO',
      filePath => '/var/log/traefik2/traefik.log',
    },
    accesslog   => {
      filePath => '/var/log/traefik2/access.log',
    },
    http        => {
      services => $services,
    },
    api         => {
      debug     => true,
      dashboard => true,
      insecure  => true,
    },
    servertransport => {
      insecureSkipVerify => true,
    },
    tls             => {
      certificates => {
        certFile => "/etc/ssl/certs/${facts[networking][fqdn]}.crt",
        keyFile  => "/etc/ssl/certs/${facts[networking][fqdn]}.key",
      }
    },
    providers        => {
      consulCatalog => {
        exposedByDefault => false,
        refreshInterval  => '5s',
        prefix           => $consul_prefix,
        endpoint         => {
          scheme   => 'https',
          address  => '127.0.0.1:8500',
          datacenter => $consul_datacenter,
          tls        => {
            insecureSkipVerify => true,
            ca                 => $consul_root_ca_file,
            cert               => $consul_cert_file,
            key                => $consul_key_file,
          }
        }
      },
      file          => {
        filename => '/etc/traefik2/dynamic.yaml',
        watch    => true,
      }
    },
  }

  $_final_static_config = deep_merge($_static_config, $_certificates_resolvers)

  class { '::traefik2':
    version        => $version,
    static_config  => $_final_static_config,
    dynamic_config => $dynamic_config,
  }

  if $manage_firewall_entry {
    $entrypoints.each | String $name, Hash $config | {
      $_port = profile_traefik2::get_port_entrypoint($config)
      $_listen_ip = profile_traefik2::get_ip_entrypoint($config)

      if $_listen_ip == '0.0.0.0' {
        $_real_listen_ip = $facts['networking']['ip']
        firewall { "00${_port} allow Traefik entrypoint ${name}":
          dport       => $_port,
          action      => 'accept',
        }
      } else {
        $_real_listen_ip = $_listen_ip
        firewall { "00${_port} allow Traefik entrypoint ${name} ${_real_listen_ip}":
          destination => $_real_listen_ip,
          dport       => $_port,
          action      => 'accept',
        }
      }
      consul::service { "traefik-endpoint-${name}":
        checks => [
          {
            tcp      => "${_real_listen_ip}:${_port}",
            interval => '10s',
          }
        ],
        port   => $_port,
      }
    }

  }

  if $expose_api {
    if $manage_firewall_entry {
      firewall { "0${traefik_api_port} allow Traefik Proxy and API/Dashboard":
        dport  => $traefik_api_port,
        action => 'accept',
      }
    }
    if $manage_sd_service {
      consul::service { $sd_service_name:
        checks => [
          {
            http     => "http://${facts[networking][ip]}:${traefik_api_port}/ping/",
            interval => '10s'
          }
        ],
        port   => $traefik_api_port,
        tags   => $sd_service_tags,
      }
    }
  }
}
