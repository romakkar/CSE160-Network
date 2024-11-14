#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"


module ForwardingP{

    uses interface Packet;
    uses interface SimpleSend;
    uses interface Receive;

    uses interface RoutingTable;
    provides interface Forwarding;
}


implementation{

    pack forwardPack; 
    uint16_t seqNum = 0;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, void* payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
    command void Forwarding.send(uint16_t dest, void *payload){
        makePack(&forwardPack, TOS_NODE_ID, dest, 255 , PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
        call SimpleSend.send(forwardPack, call RoutingTable.getNextHop(dest));
        seqNum += 1; 
    }

    event message_t* Receive.receive(message_t* m, void* payload, uint8_t length){
        pack *msg = (pack *) payload; 
        
        // dbg(ROUTING_CHANNEL, "Node %d has received packet from %d\n", TOS_NODE_ID, msg->src);

  
        if (msg->dest == TOS_NODE_ID) {
            dbg(ROUTING_CHANNEL, "Node %d received packet from %d\n", TOS_NODE_ID, msg->src);
            if(msg->protocol != PROTOCOL_PINGREPLY){
                dbg(ROUTING_CHANNEL, "%d\n", *(msg->payload));
                makePack(&forwardPack, TOS_NODE_ID, msg->src, 30 , PROTOCOL_PINGREPLY, seqNum, "ACK", PACKET_MAX_PAYLOAD_SIZE);
                call SimpleSend.send(forwardPack, call RoutingTable.getNextHop(msg->src));
            }
            else{
                dbg(ROUTING_CHANNEL, "Received ACK from %d\n", msg->src);
            }
            return m; 
        }
        msg->TTL = msg->TTL - 1;
        if (msg->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from %d, seq %d\n", msg->src, msg->seq);
            return m; 
        }

        call SimpleSend.send(*msg, call RoutingTable.getNextHop(msg->dest));

        return m; 
    }
}