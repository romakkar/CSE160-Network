#include "../../includes/packet.h"

configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery;
}

implementation{
    components NeighborDiscoveryP;
    components new TimerMilliC() as N_timer;
    components new TimerMilliC() as R_timer;
	components new SimpleSendC(1);
	components new AMReceiverC(1);
    components RoutingTableC, RandomC;

    NeighborDiscovery =  NeighborDiscoveryP.NeighborDiscovery;
    NeighborDiscoveryP.N_send -> SimpleSendC;
	NeighborDiscoveryP.N_get -> AMReceiverC;
	NeighborDiscoveryP.N_timer -> N_timer;
    NeighborDiscoveryP.R_timer -> R_timer;
    NeighborDiscoveryP.RoutingTable -> RoutingTableC;
    NeighborDiscoveryP.Random -> RandomC;
}