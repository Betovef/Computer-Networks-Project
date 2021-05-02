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
    NeighborDiscoveryC.RouteTableC -> RouteTableC; //not using RouteTable
    NeighborDiscoveryC.RoutingTableC -> HashmapC;


    components FloodingC;
    Node.FSender -> FloodingC.FSender;
    Node.RSender -> FloodingC.RSender;
    // Node.FSender -> FloodingC.FSender;

    components TransportC;
    Node.Transport->TransportC;
    TransportC.RoutingTableC -> HashmapC;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new HashmapC(Route, NEIGHBORHOOD_SIZE) as HashmapC;
    Node.RoutingTable -> HashmapC;

    components new ListC(Route, NEIGHBORHOOD_SIZE) as RouteTableC;
    Node.RouteTable -> RouteTableC;

    components new ListC(socket_t, 255) as acceptedSockets;
    Node.acceptedSockets -> acceptedSockets;

    components RoutingC;
    Node.Routing -> RoutingC;
    RoutingC.RouteTableC -> RouteTableC; //not using this -delete later
    RoutingC.HashmapC -> HashmapC;
    FloodingC.HashmapC -> HashmapC;

    components new TimerMilliC() as clientTimer;
    Node.clientTimer->clientTimer;

    components new TimerMilliC() as serverTimer;
    Node.serverTimer->serverTimer;

    components new TimerMilliC() as timeWait;
    Node.timeWait->timeWait;


    

}
