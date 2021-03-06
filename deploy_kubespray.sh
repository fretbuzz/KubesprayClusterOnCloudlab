# do this in the ssh part part?
sudo chmod 600 ~/.ssh/tempkey.pem
sudo chmod 600 ~/.ssh/tempkey.pub
eval `ssh-agent`
ssh-add ~/.ssh/tempkey.pem # TODO: automate using your password here
cd ./kubespray

istio=true
while getopts c flag
do
    case "${flag}" in
        c) istio=false;;
    esac
done

# Run the kubespray ansible playbook
ansible-playbook -i inventory/mycluster/hosts.yml  --become --become-user=root cluster.yml

# Copy kubeconfig to the home directory
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl create namespace sock-shop

if istio
then
  # install istio
  curl -L https://istio.io/downloadIstio | sh - # TODO: version control this to 1.7.0
  cd istio-1.9.3 
  export PATH=$PWD/bin:$PATH
  istioctl install --set profile=demo
  kubectl label namespace default istio-injection=enabled
  kubectl label namespace sock-shop istio-injection=enabled # TODO: handle other applications than just sockshop
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/prometheus.yaml
else
  # setup cilium
  kubectl create -f https://raw.githubusercontent.com/cilium/cilium/1.9.5/install/kubernetes/quick-install.yaml
  export CILIUM_NAMESPACE=kube-system
  kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.9.5/install/kubernetes/quick-hubble-install.yaml
fi

# Install InfluxDB
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
sudo apt-get update && sudo apt-get install influxdb
sudo service influxdb start

read  -n 1 -p "Setup the InfluxDB and Prometheus" mainmenuinput # TODO: automate this at some point.
