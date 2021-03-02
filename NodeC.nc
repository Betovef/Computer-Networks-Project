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
#include "includes/route.h"

#define NEIGHBORHOOD_SIZE 255

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    
    components NeighborDiscoveryC; 
    Node.NeighborDiscovery -> NeighborDiscoveryC;
    NeighborDiscoveryC.RouteTableC -> RouteTableC;


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

    components new HashmapC(uint16_t, NEIGHBORHOOD_SIZE) as HashmapC;
    Node.RoutingTable -> HashmapC;

    components new ListC(Route, NEIGHBORHOOD_SIZE) as RouteTableC;
    Node.RouteTable -> RouteTableC;

    components RoutingC;
    Node.Routing -> RoutingC;
    RoutingC.RouteTableC -> RouteTableC;
    RoutingC.HashmapC -> HashmapC;


    

}
