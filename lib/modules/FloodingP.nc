#include "../../includes/packet.h"
#include "../../includes/channels.h"


module FloodingP {
   provides interface Flooding;
   uses interface Packet;
   uses interface Receive;
   uses interface SimpleSend;
}

implementation {
    uint16_t cache[30];
    pack sendPackage;
    uint16_t seqNum = 1;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
    command void Flooding.send(uint16_t dest, void *payload){
        makePack(&sendPackage, TOS_NODE_ID, dest, 22, PROTOCOL_FLOOD, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
        call SimpleSend.send(sendPackage, AM_BROADCAST_ADDR);
        seqNum += 1;
    }
    event message_t* Receive.receive(message_t* m, void* payload, uint8_t length){
        pack *msg = (pack *) payload; 

        if (msg->dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "Node %d successfully received packet from %d\n", TOS_NODE_ID, msg->src);
            dbg(FLOODING_CHANNEL, "Node received packet %d\n", *(msg->payload));
            if(*(msg->payload) != 0){
                call Flooding.send(msg->src, 0);
            }
            return m; 
        }

        if (msg->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from %d, seq %d\n", msg->src, msg->seq);
            return m; 
        }

        if (cache[msg->src] == msg->seq) {
            dbg(FLOODING_CHANNEL, "Duplicate packet detected from %d, seq %d. Dropping packet.\n", msg->src, msg->seq);
            return m; 
        }

        cache[msg->src] = msg->seq;

        msg->TTL -= 1;
        if (msg->TTL > 0) {
            dbg(FLOODING_CHANNEL, "Rebroadcasting packet from %d with TTL %d\n", msg->src, msg->TTL);
            call SimpleSend.send(*msg, AM_BROADCAST_ADDR);  // Rebroadcast the modified packet
        }
        
        return m; 
    }
}