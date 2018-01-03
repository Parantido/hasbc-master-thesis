include(`defines.m4')
define(`STATE', `MASTER')dnl
define(`PRIORITY', `100')dnl
define(`INTERNAL_IFACE', `NODE2_INTERNAL_IFACE')dnl
define(`EXTERNAL_IFACE', `NODE2_EXTERNAL_IFACE')dnl
include(`keepalived-template.m4')
