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
```
bash <(https://raw.githubusercontent.com/inipew/sbx-cfg/main/install.sh)
```    
If you want install specific version,plz use coomand line as follows:
```
bash <(https://raw.githubusercontent.com/inipew/sbx-cfg/main/install.sh) install 1.0.3
```
# quick start
Just type `sing-box` to enter control menu,as follows showed here:
```
  sing-box-v0.0.2 Management Scripts
  0. Exit Script
————————————————
  1. Installing the sing-box service
  2. Updating the sing-box service
  3. Uninstalling the sing-box service
  4. Start the sing-box service
  5. Stop sing-box service
  6. Restart the sing-box service
  7. Viewing sing-box status
  8. Viewing the sing-box log
  9. Clear the sing-box log
  A. Checking the sing-box configuration
————————————————
  B. Setting the sing-box to boot up
  C. Cancel sing-box boot-up
  D. Set sing-box to clear logs & reboot regularly
  E. Cancel sing-box timer to clear logs & reboot
————————————————
  F. Key to turn on bbr 
  G. Key to apply for an SSL certificate 
```   
# examples  
- client_config.json will be used as client config,inbound:`tun`,outbound:`shadowsocks`  
- server_config.json will be used as server config,inbound:`shadowcoks`,outbound:`direct` 


# Credit
- This script belongs to [FranzKafkaYu](https://github.com/FranzKafkaYu)
