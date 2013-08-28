# Load attributes from Encrypted DataBag if any
begin
  databag = Chef::EncryptedDataBagItem.load(node["strongloop"]["databag_name"], "secrets")
rescue
  Chef::Log.debug("No databag found. Using attributes.")
end

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
begin
  plain_pass = databag['strongloop']['password']
rescue
  if node['strongloop']['password'].nil?
    plain_pass = secure_password
  else
    plain_pass = node['strongloop']['password']
  end
end

# Create hash from password
if node['strongloop']['shadow_hash'].nil?
  salt = rand(36**8).to_s(36)
  shadow_hash = plain_pass.crypt("$6$" + salt)
  node.set_unless['strongloop']['shadow_hash'] = shadow_hash
end

chef_gem "ruby-shadow"

user node['strongloop']['username'] do
  supports :manage_home => true
  comment "StrongLoop User"
  shell "/bin/bash"
  home "/home/#{node['strongloop']['username']}"
  password node['strongloop']['shadow_hash']
  action :create
end

remote_file ::File.join(Chef::Config[:file_cache_path], "strongloop.package") do
  source node['strongloop']['package']['url']
  owner node['strongloop']['username']
  group node['strongloop']['username']
  mode 00644
end

bash "strongloop-node" do
  cwd Chef::Config[:file_cache_path]
  case node["platform_family"]
    when "debian"
      provider = "dpkg"
      exists = "dpkg -L |grep strongloop"
    when "rhel"
      provider = "rpm"
      exists = "rpm -qa |grep strongloop"
    end
  code "#{provider} -i #{::File.join(Chef::Config[:file_cache_path], 'strongloop.package')}"
  not_if "#{exists}"
  action :run
end
