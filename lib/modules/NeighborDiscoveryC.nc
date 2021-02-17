// #include <Timer.h>
// #include "../../includes/CommandMsg.h"
// #include "../../includes/packet.h"

#define AM_NEIGH 14

configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery;
    // uses interface Hashmap<uint16_t> as NListC;
}
implementation{
    
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    components new ListC(pack, 4);
    NeighborDiscoveryP.NList -> ListC;

    // NeighborDiscoveryP.NList = NListC;

    components new TimerMilliC() as PeriodicTimer;
    NeighborDiscoveryP.PeriodicTimer -> PeriodicTimer; // Timer to send neighbor dircovery packets periodically

    components new AMReceiverC(AM_NEIGH);
    NeighborDiscoveryP.NReceiver -> AMReceiverC;

    components new SimpleSendC(AM_NEIGH); 
    NeighborDiscoveryP.NSender -> SimpleSendC;

    components RandomC as RandomTimer;
    NeighborDiscoveryP.RandomTimer -> RandomTimer;
    
    
}