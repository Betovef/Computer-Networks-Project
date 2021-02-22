#define AM_FLOOD 13

configuration FloodingC{
    provides interface SimpleSend as FSender;
}
implementation{

    components FloodingP;
    // Flooding = FloodingP.Flooding;
    
    components NeighborDiscoveryC;
    FloodingP.NeighborDiscovery -> NeighborDiscoveryC;

    // components new ListC(pack, 4);
    // FloodingP.NList -> ListC;

    components new AMReceiverC(AM_FLOOD);
    // FloodingP.FReceiver -> AMReceiverC;
    FloodingP.InternalReceiver -> AMReceiverC;

    components new SimpleSendC(AM_FLOOD); 
    FSender = FloodingP.FSender;
    FloodingP.InternalSender -> SimpleSendC;
}