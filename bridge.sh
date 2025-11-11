## this scripts containt steps to create a bridge to give local macos access to wifi network 
### install bridge utils 
sudo apt install bridge-utils 

### create bridge br0
sudo brctl addbr br0
sudo brctl addif br0 wlp0s20f3 #add wifi adapter to the bridge 
sudo ip link set br0 up

## creating macvtap interface 
sudo ip link add link wlp0s20f3 name macvtap0 type macvtap mode bridge
sudo ip link set macvtap0 up

