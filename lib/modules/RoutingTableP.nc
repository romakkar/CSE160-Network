#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define MAX_ENTRIES 256

module RoutingTableP {
    uses interface NeighborDiscovery;

    provides interface RoutingTable;    
}

implementation {
    RoutingTableEntry RoutingTableS[MAX_ENTRIES];
    uint16_t counter = 0; 
    pack myMsg;

    command void RoutingTable.start(){
        uint16_t i;
        for(i = 0; i < 256; i++){
            RoutingTableS[i].cost = 65535;
        }
        RoutingTableS[TOS_NODE_ID].cost = 0;
        RoutingTableS[TOS_NODE_ID].nextHop = TOS_NODE_ID;
    }

    command void RoutingTable.addNeighbor(uint16_t dest, uint16_t cost){
        if(RoutingTableS[dest].nextHop == dest){
            RoutingTableS[dest].cost = cost;
            RoutingTableS[dest].nextHop = dest;
        }
        if(RoutingTableS[dest].cost > cost){
            RoutingTableS[dest].cost = cost;
            RoutingTableS[dest].nextHop = dest;
        }
    }

    command void RoutingTable.addRoutingTableEntry(RoutingTableEntry* entries, uint8_t seq) {
        uint8_t i = 0;
        for(i = 0; i < 5; i++){
            if (entries[i].cost < RoutingTableS[seq*5 + i+1].cost || entries[i].nextHop == RoutingTableS[seq*5 + i+1].nextHop) {
                RoutingTableS[seq*5 + i+1] = entries[i];
                if(counter < seq*5 + i+1){
                    counter = seq*5 + i+1;
                }
            }
        }
    }

    command void* RoutingTable.sendRoutingTable() {
        return RoutingTableS; 
    }
    
    command uint8_t RoutingTable.getNextHop(uint16_t dest){
        return RoutingTableS[dest].nextHop; 
    }

    command void RoutingTable.printTable(){
        uint16_t i = 1;
        dbg(ROUTING_CHANNEL, "Dest\tCost\tNextHop\n");
        for(i = 1; i < counter; i++){
            dbg(ROUTING_CHANNEL, "%d\t\t%d\t%d\n", i, RoutingTableS[i].cost, RoutingTableS[i].nextHop);
        }
    }
}