#include "../../includes/packet.h"

module NeighborDiscoveryP{
    uses interface Timer<TMilli> as N_timer;
    uses interface Timer<TMilli> as R_timer;
    uses interface SimpleSend as N_send;
    uses interface Receive as N_get;
    uses interface RoutingTable;
    uses interface Random;
    provides interface NeighborDiscovery;
}

implementation{
    RoutingTableEntry rTable[5];
    pack sendPackage;
    uint16_t MAX_COST = 65535;
    uint16_t Neighbors[256];
    uint16_t PrevLoss[256];
    uint16_t i = 0;
    
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
    command void NeighborDiscovery.start(){
		dbg( NEIGHBOR_CHANNEL, "Initializing Neighbor Discovery\n");
        for(i = 0; i < 256; i++){
            Neighbors[i] = MAX_COST;
            PrevLoss[i] = MAX_COST;
        }
        call RoutingTable.start();
		call N_timer.startPeriodic(9999 - (call Random.rand16() % 400 + 100));
	}
    command void NeighborDiscovery.printNeighbor(){
        dbg(NEIGHBOR_CHANNEL, "I(%d) am printing neighbors\n", TOS_NODE_ID);
        for(i = 0; i < 256; i++){
            if(PrevLoss[i] != MAX_COST){
                dbg(NEIGHBOR_CHANNEL, "I(%d) am neighbors with %d with packet loss:%d\n", TOS_NODE_ID, i, PrevLoss[i]);
            }
        }
    }
    event void N_timer.fired(){
        RoutingTableEntry* T = (RoutingTableEntry *)(call RoutingTable.sendRoutingTable());
        for(i = 0; i < 51; i++){
            uint8_t j = 0;
            for(j = 0; j < 5; j++){
                rTable[j] = T[5*i + j+1];
            }
		    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PING, i, (void *)rTable, PACKET_MAX_PAYLOAD_SIZE);
		    call N_send.send(sendPackage, sendPackage.dest);
        }
		// dbg(NEIGHBOR_CHANNEL, "%d is searching for neighbors\n", TOS_NODE_ID);
        call R_timer.startOneShot(100);
	}
    event void R_timer.fired(){
        for(i = 1; i < 256; i++){
            PrevLoss[i] = Neighbors[i];
            Neighbors[i] = MAX_COST;
        }
	}
    event message_t* N_get.receive(message_t* m, void* payload, uint8_t len){
		pack *msg = (pack *) payload;
        // dbg(NEIGHBOR_CHANNEL, "Receiving packet %d\n", msg->src);
        if (msg->protocol == PROTOCOL_PINGREPLY){
            if(Neighbors[msg->src] == MAX_COST){
                Neighbors[msg->src] = 50;
            }
            Neighbors[msg->src]--;
            call RoutingTable.addNeighbor(msg->src, (Neighbors[msg->src] < PrevLoss[msg->src]) ? Neighbors[msg->src] : PrevLoss[msg->src]);
            return m;
        }
        for(i = 0; i < 5; i++){
            rTable[i] = ((RoutingTableEntry *)(msg->payload))[i];
            if(rTable[i].cost == MAX_COST){
                continue;
            }
            rTable[i].cost += PrevLoss[msg->src];
            rTable[i].nextHop = msg->src;
            call RoutingTable.addRoutingTableEntry(rTable, msg->seq);
        }
        msg->dest = msg->src;
        msg->src = TOS_NODE_ID;
        msg->protocol = PROTOCOL_PINGREPLY;
        call N_send.send(*msg, msg->dest);
		return m;
	}
}