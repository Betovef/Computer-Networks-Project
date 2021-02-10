// #include <Timer.h>
// #include "../../includes/CommandMsg.h"
// #include "../../includes/packet.h"

#define AM_NEIGH 14

configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery;
    // uses interface Hashmap<uint16_t> as NHashmapC;
}
implementation{
    
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    components new HashmapC(uint16_t, 4);
    NeighborDiscoveryP.NHashmap -> HashmapC;

    // NeighborDiscoveryP.NHashmap = NHashmapC;

    components new TimerMilliC() as PeriodicTimer;
    NeighborDiscoveryP.PeriodicTimer -> PeriodicTimer; // Timer to send neighbor dircovery packets periodically

    components new AMReceiverC(AM_NEIGH);
    NeighborDiscoveryP.NReceiver -> AMReceiverC;

    components new SimpleSendC(AM_NEIGH); 
    NeighborDiscoveryP.NSender -> SimpleSendC;

    components RandomC as RandomTimer;
    NeighborDiscoveryP.RandomTimer -> RandomTimer;
    
    
}