include(`defines.m4')dnl
\c opensips
DELETE FROM load_balancer;
DELETE FROM clusterer;
DELETE FROM dispatcher;
INSERT INTO load_balancer (id, group_id, dst_uri, resources) VALUES (1, 1, 'sip:INTERNAL_SOFTPHONE_IP:DEFAULT_SIP_PORT', 'pstn=100');
INSERT INTO load_balancer (id, group_id, dst_uri, resources) VALUES (2, 1, 'sip:INTERNAL_SOFTPHONE2_IP:DEFAULT_SIP_PORT', 'pstn=100');
INSERT INTO clusterer (id, cluster_id, node_id, url, description) VALUES (1, 1, NODE1_CLUSTERER_ID, 'NODE1_INTERNAL_IP:DEFAULT_SIP_PORT', 'Node 1');
INSERT INTO clusterer (id, cluster_id, node_id, url, description) VALUES (2, 1, NODE2_CLUSTERER_ID, 'NODE2_INTERNAL_IP:DEFAULT_SIP_PORT', 'Node 2');
INSERT INTO dispatcher (setid, destination) VALUES (1, 'sip:REGISTRAR_IP:REGISTRAR_PORT');
INSERT INTO dispatcher (setid, destination) VALUES (1, 'sip:REGISTRAR2_IP:REGISTRAR_PORT');
