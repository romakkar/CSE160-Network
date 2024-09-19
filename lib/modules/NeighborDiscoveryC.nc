configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery
}

implementation{
    components  NeighborDiscovery;
    Flooding =  NeighborDiscoveryP.NeighborDiscovery;
}