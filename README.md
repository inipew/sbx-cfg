# sing-box-yes    
Install sing-box easily:100:  

sing-box is a universal proxy platform which supports many protocols.Currently it supports:  

`inbound`： 
- Shadowsocks(including shadowsocks2022)    
- Vmess  
- Trojan  
- Naive  
- Hysteria  
- ShadowTLS  
- Tun  
- Redirect  
- TProxy  
- Socks  
- HTTP  

`outbound`:  
- Shadowsocks(including shadowsocks2022)    
- Vmess  
- Trojan 
- Wireguard  
- Hysteria  
- ShadowTLS  
- ShadowsocksR  
- VLESS  
- Tor  
- SSH

For more details,please check here:point_right:[official site](https://sing-box.sagernet.org/)
# usage
To install latest stable version:
```
bash <(curl -Ls https://raw.githubusercontent.com/inipew/sbx-cfg/test/install.sh)
```    
If you want install latest prerelease version,plz use coomand line as follows:
```
bash <(curl -Ls https://raw.githubusercontent.com/inipew/sbx-cfg/test/install.sh) install 1
```
or you can using sing-box version like this
```
bash <(curl -Ls https://raw.githubusercontent.com/inipew/sbx-cfg/test/install.sh) install 1.3.1-beta3
```
If you want to update to the latest release version after installation and keep the original configuration file, use the following command or update via menu option ``2``.  
```
sing-box update 
```
If you want to update to a prerelease version  after installation, and keep the configuration file, use the following command to update.
```
sing-box update 1
```
```
sing-box update 1.3.1-beta3
```
# quick start
Just type `sing-box` to enter control menu,as follows showed here:
```
sing-box-v0.0.2 Management Scripts
0. Exit Script
------------------------------------------
1. Core Management
2. Viewing sing-box status
3. View sing-box log
4. Account Management
------------------------------------------
5. Checking the sing-box configuration
6. Show boot menu
7. Show Other Menu
```   
# examples  
- client_config.json will be used as client config,inbound:`tun`,outbound:`shadowsocks`  
- server_config.json will be used as server config,inbound:`shadowcoks`,outbound:`direct` 


# Credit
- This script belongs to [FranzKafkaYu](https://github.com/FranzKafkaYu)
