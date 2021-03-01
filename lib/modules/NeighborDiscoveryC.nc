#define AM_NEIGH 60
#define NEIGHBORHOOD_SIZE 20

configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery;
}
implementation{
    
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    // components FloodingC;
    // NeighborDiscoveryP.Flooding -> FloodingC;

    components new ListC(pack, NEIGHBORHOOD_SIZE) as PacketListC;
    NeighborDiscoveryP.PacketList-> PacketListC;

    components new ListC(uint16_t, NEIGHBORHOOD_SIZE) as NeighborListC;
    NeighborDiscoveryP.NeighborList->NeighborListC;

    components new TimerMilliC() as PeriodicTimer;
    NeighborDiscoveryP.PeriodicTimer -> PeriodicTimer; // Timer to send neighbor dircovery packets periodically

    components new AMReceiverC(AM_NEIGH);
    NeighborDiscoveryP.NReceiver -> AMReceiverC;

    components new SimpleSendC(AM_NEIGH); 
    NeighborDiscoveryP.NSender -> SimpleSendC;


    components RandomC as RandomTimer;
    NeighborDiscoveryP.RandomTimer -> RandomTimer;
    
    
}