Puppet::Functions.create_function(:'profile_traefik2::get_ip_entrypoint') do
  dispatch :get_ip_entrypoint do
    param 'Hash', :config
    return_type 'String'
  end

  # Reformat the following hash:
  #
  #  { address => '0.0.0.0:80', }
  #   
  # Into the following string:
  #
  #   0.0.0.0
  #
  # This function can be used for generating additional resources like the firewall
  def get_ip_entrypoint(config)
    config['address'].split(':')[0]
  end
end
