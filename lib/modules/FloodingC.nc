
#define AM_FLOOD 18

configuration FloodingC{
    provides interface SimpleSend as FSender;
    provides interface SimpleSend as RSender;
    uses interface Hashmap<Route> as HashmapC;
}
implementation{

    components FloodingP;
    FloodingP.RoutingTable = HashmapC;
    // Flooding = FloodingP.Flooding;
    
    components NeighborDiscoveryC;
    FloodingP.NeighborDiscovery -> NeighborDiscoveryC;

    // components new ListC(pack, 4);
    // FloodingP.NList -> ListC;

    components new ListC(pack, 20) as PacketListC;
    FloodingP.PacketList-> PacketListC;

    components new AMReceiverC(AM_FLOOD);
    // FloodingP.FReceiver -> AMReceiverC;
    FloodingP.InternalReceiver -> AMReceiverC;

    components new SimpleSendC(AM_FLOOD); 
    FSender = FloodingP.FSender;
    RSender = FloodingP.RSender;
    FloodingP.InternalSender -> SimpleSendC;
}
