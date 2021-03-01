/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

#define NEIGHBORHOOD_SIZE 4

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    
    components NeighborDiscoveryC; 
    Node.NeighborDiscovery -> NeighborDiscoveryC;


    components FloodingC;
    Node.FSender -> FloodingC.FSender;
    // Node.FSender -> FloodingC.FSender;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components RoutingTableC;
    Node.RoutingTable -> RoutingTableC;
}
