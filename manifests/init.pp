#
class profile_traefik2 (
  Hash                 $entrypoints,
  String               $consul_datacenter,
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
  Boolean              $manage_sd_service            = lookup('manage_sd_service', Boolean, first, true),
) {
  openssl::certificate::x509 { $facts['networking']['fqdn']:
    country      => 'BE',
    organization => $facts['networking']['domain'],
    commonname   => $facts['networking']['fqdn'],
    altnames     => $service_domain_names,
  }

  $_static_config = {
    entryPoints => $entrypoints,
    log         => '/var/log/traefik2/traefik.log',
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
          }
        }
      },
      file          => {
        filename => '/etc/traefik2/dynamic.yaml',
        watch    => true,
      }
    },
  }

  class { '::traefik2':
    version        => $version,
    static_config  => $_static_config,
    dynamic_config => $dynamic_config,
  }

  if $manage_firewall_entry {
    $entrypoints.each | String $name, Hash $config | {
      $_port = profile_traefik2::get_port_entrypoint($config)
      firewall { "00${_port} allow Traefik entrypoint ${name}":
        dport  => $_port,
        action => 'accept',
      }
      consul::service { "Traefik endpoint ${name}":
        checks => [
          {
            tcp      => "${facts[networking][ip]}:${_port}",
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
