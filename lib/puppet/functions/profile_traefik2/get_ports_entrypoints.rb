Puppet::Functions.create_function(:'profile_traefik2::get_ports_entrypoints') do
  dispatch :get_ports_entrypoints do
    param 'Hash', :entrypoints
    return_type 'Array'
  end

  # Reformat the following hash:
  #
  #   {
  #     http => {
  #       address => '0.0.0.0:80',
  #     },
  #     https => {
  #       address => '0.0.0.0:443'.
  #     },
  #   }
  #   
  # Into the following hash
  #
  #   [ http  => 80, https => 443 ]
  #
  # This function can be used for generating additional resources like the firewall
  def get_port_entrypoints(entrypoints)
    result = Array.new
    entrypoints.each |key, value| do
      port = value['address'].split(':')[-1]
      result << Hash[ key => port ]
    end
  end
end
