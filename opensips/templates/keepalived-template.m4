global_defs {
        enable_script_security
        script_user keepalived_script keepalived_script
}
vrrp_instance VI_1 {
    interface EXTERNAL_IFACE
    state STATE
    virtual_router_id 54
    priority PRIORITY
    advert_int 1
    virtual_ipaddress {
        VRRP_EXTERNAL_IP
    }
    notify /home/keepalived_script/notify-keepalived.sh
}

vrrp_instance VI_2 {
    interface INTERNAL_IFACE
    state STATE
    virtual_router_id 55
    priority PRIORITY
    advert_int 1
    virtual_ipaddress {
        VRRP_INTERNAL_IP
    }
    notify /home/keepalived_script/notify-keepalived.sh
}
