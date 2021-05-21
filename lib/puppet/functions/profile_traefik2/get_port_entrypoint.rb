Puppet::Functions.create_function(:'profile_traefik2::get_port_entrypoint') do
  dispatch :get_port_entrypoint do
    param 'Hash', :config
    return_type 'Integer'
  end

  # Reformat the following hash:
  #
  #  { address => '0.0.0.0:80', }
  #   
  # Into the following integer:
  #
  #   80
  #
  # This function can be used for generating additional resources like the firewall
  def get_port_entrypoint(config)
    Integer(config['address'].split(':')[-1])
  end
end
