#include "../../includes/packet.h"
interface RoutingTable{
    command void start();

    command void addNeighbor(uint16_t dest, uint16_t cost);

    command void addRoutingTableEntry(RoutingTableEntry* entries, uint8_t seq);
    
    command void* sendRoutingTable();
     
    command uint8_t getNextHop(uint16_t dest);
    
    command void printTable();
}