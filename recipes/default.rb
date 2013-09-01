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

#=begin
# some extra commands to create samples

#make samples folder
directory node['strongloop']['demofolder'] do
  owner node['strongloop']['username']
  group node['strongloop']['username']
  action :create
end

#create the default app
bash "slc-create-sample" do
  cwd node['strongloop']['demofolder']
  code "slnode create web sampleApp"
end

#install git
bash "install-git" do
  #code "sudo apt-get update"
  code "sudo apt-get --yes --force-yes install git"
end

#clone slnode examples
bash "clone-slnode-examples" do
  cwd node['strongloop']['demofolder']
  code "git clone https://github.com/strongloop/slnode-examples"
end

#install strong-agent -global
bash "install-npm-strong-agent" do
  code "sudo npm install -g strong-agent"
end

#install forever -global 
bash "install-npm-forever" do
  code "sudo npm install -g forever"
end

#clone the fib sample
bash "clone-fib" do
  cwd node['strongloop']['demofolder']
  code "git clone https://github.com/strongloop-community/fib"
end

#install strong-agent for fib
bash "install-npm-strong-agent" do
  cwd "/home/#{node['strongloop']['username']}/samples/fib"
  code "sudo npm install strong-agent"
end

#run the fib sample app with forever
bash "forever-fib" do
  cwd "/home/#{node['strongloop']['username']}/samples/fib"
  code "sudo forever start app.js"
end
#=end
