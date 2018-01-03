#
# OpenSIPS loadbalancer script
#     by OpenSIPS Solutions <team@opensips-solutions.com>
#
# This script was generated via "make menuconfig", from
#   the "Load Balancer" scenario.
# You can enable / disable more features / functionalities by
#   re-generating the scenario with different options.
#
# Please refer to the Core CookBook at:
#      http://www.opensips.org/Resources/DocsCookbooks
# for a explanation of possible statements, functions and parameters.
#


####### Global Parameters #########

log_level=3
log_stderror=no
log_facility=LOG_LOCAL0

children=4

/* uncomment the following lines to enable debugging */
#debug_mode=yes

/* uncomment the next line to enable the auto temporary blacklisting of
   not available destinations (default disabled) */
#disable_dns_blacklist=no

/* uncomment the next line to enable IPv6 lookup after IPv4 dns
   lookup failures (default disabled) */
#dns_try_ipv6=yes

/* comment the next line to enable the auto discovery of local aliases
   based on revers DNS on IPs */
auto_aliases=no


listen=udp:VRRP_INTERNAL_IP:DEFAULT_SIP_PORT   # CUSTOMIZE ME
listen=udp:VRRP_EXTERNAL_IP:DEFAULT_SIP_PORT
listen=bin:INTERNAL_IP:DEFAULT_SIP_PORT

####### Modules Section ########

#set module path
mpath="/usr/local/lib64/opensips/modules/"
loadmodule "topology_hiding.so"
modparam("topology_hiding", "force_dialog", 1)


#### SIGNALING module
loadmodule "signaling.so"

#### StateLess module
loadmodule "sl.so"

#### Transaction Module
loadmodule "tm.so"
modparam("tm", "fr_timeout", 5)
modparam("tm", "fr_inv_timeout", 30)
modparam("tm", "restart_fr_on_each_reply", 0)
modparam("tm", "onreply_avp_mode", 1)

#### Record Route Module
loadmodule "rr.so"
/* do not append from tag to the RR (no need for this script) */
modparam("rr", "append_fromtag", 0)

#### MAX ForWarD module
loadmodule "maxfwd.so"

#### SIP MSG OPerationS module
loadmodule "sipmsgops.so"

#### FIFO Management Interface
loadmodule "mi_fifo.so"
modparam("mi_fifo", "fifo_name", "/tmp/opensips_fifo")
modparam("mi_fifo", "fifo_mode", 0666)

#### URI module
loadmodule "uri.so"
modparam("uri", "use_uri_table", 0)

loadmodule "proto_bin.so"
modparam("proto_bin", "bin_port", 5062)

loadmodule "clusterer.so"
modparam("clusterer", "db_url", "postgres://POSTGRES_U_AND_PWD@DB_HOST/opensips")
modparam("clusterer", "current_id", CLUSTERER_CURRENT_ID)
loadmodule "db_postgres.so"

#### AVPOPS module
loadmodule "avpops.so"

#### ACCounting module
loadmodule "acc.so"
/* what special events should be accounted ? */
modparam("acc", "early_media", 0)
modparam("acc", "report_cancels", 0)
/* by default we do not adjust the direct of the sequential requests.
   if you enable this parameter, be sure the enable "append_fromtag"
   in "rr" module */
modparam("acc", "detect_direction", 0)


#### DIALOG module
loadmodule "dialog.so"
modparam("dialog", "dlg_match_mode", 1)
modparam("dialog", "default_timeout", 21600)  # 6 hours timeout
modparam("dialog", "db_mode", 1)
modparam("dialog", "db_url", "postgres://POSTGRES_U_AND_PWD@DB_HOST/opensips")
modparam("dialog", "accept_replicated_dialogs", 1)
modparam("dialog", "replicate_dialogs_to", 1)
modparam("dialog", "replicate_profiles_to", 1)
modparam("dialog", "accept_replicated_profiles", 1)

#### LOAD BALANCER module
loadmodule "load_balancer.so"
modparam("load_balancer", "db_url", "postgres://POSTGRES_U_AND_PWD@DB_HOST/opensips")
modparam("load_balancer", "probing_method", "OPTIONS")
modparam("load_balancer", "probing_interval", 30)
modparam("load_balancer", "replicate_status_to", 1)
modparam("load_balancer", "accept_replicated_status", 1)

loadmodule "dispatcher.so"
modparam("dispatcher", "db_url", "postgres://POSTGRES_U_AND_PWD@DB_HOST/opensips")

loadmodule "proto_udp.so"
loadmodule "usrloc.so"
modparam("usrloc", "db_mode", 0)
modparam("usrloc", "db_url", "postgres://POSTGRES_U_AND_PWD@DB_HOST/opensips")
modparam("usrloc", "accept_replicated_contacts", 1)
modparam("usrloc", "replicate_contacts_to", 1)

loadmodule "mid_registrar.so"
modparam("mid_registrar", "mode", 1) /* 0 = mirror / 1 = ct / 2 = AoR */
modparam("mid_registrar", "outgoing_expires", 7200)
modparam("mid_registrar", "insertion_mode", 0) /* 0 = contact; 1 = path */

loadmodule "pike.so"
modparam("pike", "check_route", "pike")

####### Routing Logic ########

# main request routing logic

route{
    if (!mf_process_maxfwd_header("10")) {
        sl_send_reply("483","Too Many Hops");
        exit;
    }

    if (has_totag()) {
        if (topology_hiding_match()) {
            xlog("=================================================================");
            xlog("Succesfully matched this request to a topology hiding dialog. \n");
            xlog("Calller side callid is $ci \n");
            xlog("Callee side callid  is $TH_callee_callid \n");
            xlog("=================================================================");
            route(RELAY);
        }
        else {
            xlog("===============TOPOLOGY HIDING DID NOT MATCH====================");
            if ( is_method("ACK") ) {
                xlog("L_ERR", "============ METHOD ACK   ============");
                if ( t_check_trans() ) {
                    # non loose-route, but stateful ACK; must be an ACK after
                    # a 487 or e.g. 404 from upstream server
                    t_relay();
                    exit;
                } else {
                    xlog("L_ERR", "============ ACK WITHOUT MATCHING TRANSACTION ============");
                    # ACK without matching transaction ->
                    # ignore and discard
                    exit;
                }
            }
            sl_send_reply("404","Not here");
        }
        exit;
    }

    #### INITIAL REQUESTS

    if (is_method("REGISTER")) {
        xlog("INITIAL_REGISTER \n");
        mid_registrar_save("location");
        switch ($retcode) {
        case 1:
            xlog("forwarding REGISTER to main registrar ($$ci=$ci)\n");
            if ( !ds_select_dst("1", "6") ) { # setid=1, alg=6 random
                send_reply("500","Unable to route");
                exit;
            }
            xlog("Selected REG trunk $rd/$du \n");
            t_on_failure("REG_FAILOVER");

            route(RELAY);
        case 2:
            xlog("absorbing REGISTER! ($$ci=$ci)\n");
            break;
        default:
            xlog("failed to save registration! ($$ci=$ci)\n");
        }

        exit;
    }
    # initial requests from main registrar, need to look them up!
    if (is_method("INVITE|MESSAGE") && ds_is_in_list("$si", "$sp", "1")) {
        xlog("looking up $ru!\n");
        if (!mid_registrar_lookup("location")) {
            t_reply("404", "Not Found");
            exit;
        }
        route(RELAY);
        exit;
    }

    # CANCEL processing
    if (is_method("CANCEL")) {
        if (t_check_trans())
            route(RELAY);
            exit;
    }
    else if (!is_method("INVITE")) {
        send_reply("405","Method Not Allowed");
        exit;
    }
    else {
        create_dialog();
    }

    if ($rU==NULL) {
        # request with no Username in RURI
        sl_send_reply("484","Address Incomplete");
        exit;
    }

    t_check_trans();

    # preloaded route checking
    if (loose_route()) {
        xlog("L_ERR",
        "Attempt to route with preloaded Route's [$fu/$tu/$ru/$ci]");
        if (!is_method("ACK"))
            sl_send_reply("403","Preload Route denied");
        exit;
    }

    # record routing
    record_route();

    do_accounting("log");

    topology_hiding("UC");  
    if ( !load_balance("1","pstn")) {
        send_reply("500","No Destination available");
        exit;
    }
    t_on_failure("GW_FAILOVER");
    route(RELAY);
}


route[RELAY] {
    if (is_method("INVITE|REGISTER")) {
        if ($Ri=="VRRP_EXTERNAL_IP" && $Rp=="DEFAULT_SIP_PORT") {
            xlog("L_INFO","ToInternal message");
            route("ToInternal");
         } else if ($Ri=="VRRP_INTERNAL_IP" && $Rp=="DEFAULT_SIP_PORT") {
            xlog("L_INFO","ToExternal message");
            route("ToExternal");
        } 
    }
    if (!t_relay()) {
        sl_reply_error();
    };
    exit;
}

route[ToInternal] {
    xlog("L_INFO","route(ToInternal)");
    force_send_socket(UDP:VRRP_INTERNAL_IP:DEFAULT_SIP_PORT);
}

route[ToExternal] {
    xlog("L_INFO","route(ToExternal)");
    force_send_socket(UDP:VRRP_EXTERNAL_IP:DEFAULT_SIP_PORT); 
}

route[pike] {
    if ds_is_in_list("$si", "$sp", "1"){
        drop;
    }
    if lb_is_destination("$si","$sp"){
        drop;
    }
} 



failure_route[GW_FAILOVER] {
    if (t_was_cancelled()) {
            exit;
    }

    # failure detection with redirect to next available trunk
    if (t_check_status("(408)|([56][0-9][0-9])")) {
        xlog("Failed trunk $rd/$du detected \n");
        if ( lb_next() ) {
            t_on_failure("GW_FAILOVER");
            t_relay();
            exit;
        }
        send_reply("500","All GW are down");
    }
}

failure_route[REG_FAILOVER] {
    xlog("REG_FAILOVER \n");
    if (t_was_cancelled()) {
            exit;
    }

    # failure detection with redirect to next available trunk
    if (t_check_status("(408)|([56][0-9][0-9])")) {
        xlog("Failed REG trunk $rd/$du detected \n");
        if ( ds_next_dst() ) {

            t_on_failure("REG_FAILOVER");
            xlog("DS_NEXT_DST \n");
            t_relay();
            exit;
        }

        send_reply("500","All REG GW are down");
    }

}


local_route {
    if (is_method("BYE") && $DLG_dir=="UPSTREAM") {

        acc_log_request("200 Dialog Timeout");

    }
}
