#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define AM_ROUTING 63

configuration RoutingTableC{
    provides interface RoutingTable;
}

implementation{
    components RoutingTableP;
    

    components NeighborDiscoveryC;
    RoutingTableP.NeighborDiscovery -> NeighborDiscoveryC;
    
    RoutingTable = RoutingTableP.RoutingTable;
    

}