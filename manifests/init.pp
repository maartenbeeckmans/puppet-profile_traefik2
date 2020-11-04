#
class profile_traefik2 (
  Hash                 $dynamic_config        = {},
  Hash                 $static_config         = {},
  String               $version               = '2.3.2',
  Boolean              $expose_api            = true,
  Boolean              $expose_metrics        = true,
  Boolean              $expose_ui             = false,
  Boolean              $manage_firewall_entry = true,
  Boolean              $manage_sd_service     = false,
  Enum['http','https'] $protocol              = 'https',
  String               $sd_service_name       = 'traefik',
  Array                $sd_service_tags       = ['metrics'],
  Integer              $traefik_api_port      = 8080,
) {
  class { '::traefik2':
    dynamic_config => $dynamic_config,
    version        => $version,
    static_config  => $static_config,
  }

  if $manage_firewall_entry {
    if $protocol == 'https' {
      firewall { '00443 allow Traefik HTTPS':
        dport  => '443',
        action => 'accept',
      }
    } else {
      firewall { '00080 allow Traefik HTTPS':
        dport  => '80',
        action => 'accept',
      }
    }
  }

  if $expose_api {
    if $expose_ui {
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
              http     => "http://${::ipaddress}:${traefik_api_port}/ping/",
              interval => '10s'
            }
          ],
          port   => $traefik_api_port,
          tags   => $sd_service_tags,
        }
      }
    }
  }
}
