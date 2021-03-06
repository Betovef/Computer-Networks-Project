#include "../../includes/route.h"
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#define TABLE_SIZE 20 //change value accordingly
#define MAX_TTL 10;

module RoutingP{
    provides interface Routing;

    uses interface Timer<TMilli> as RoutingTimer;
    uses interface SimpleSend as RSender;
    uses interface Receive as InternalReceiver;
    uses interface NeighborDiscovery;
    uses interface Random as RandomTimer;
    uses interface List<uint16_t> as NeighborList;
    uses interface Hashmap<Route> as RoutingTable;
    uses interface List<Route> as RouteTable;

}
implementation{  
    uint16_t i, j;
    uint16_t neighbor;
    uint16_t listSize;
    uint16_t seqNum = 0;
    Route packet; 
    pack sendPackage;
    void mergeRoutes();
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

    //Periodic timer for updating the routing table
    command void Routing.start(){
        dbg(ROUTING_CHANNEL, "Starting Routing timer: 8000\n");
        call RoutingTimer.startPeriodic(10000);  //80000 + (uint16_t)((call RandomTimer.rand16())%10000)
    }

    event void RoutingTimer.fired(){
        mergeRoutes();
    }

    command void Routing.initializeTable(){
        Route newPacket;
        listSize = call RoutingTable.size();
        for(i = 1; i< TABLE_SIZE; i++){
            newPacket.dest = i;
            if(i == TOS_NODE_ID){
                newPacket.cost = 0;
                newPacket.nextHop = i;
                call RoutingTable.insert(i, newPacket);
            }
            else{
                newPacket.cost = 255; // "infinity"
                newPacket.nextHop = 0;
                call RoutingTable.insert(i, newPacket);
            }
            
        }
    }

    void mergeRoutes(){
        Route DVRinfo;
        Route *DVRinfop;
        listSize = call NeighborList.size();
        // dbg(ROUTING_CHANNEL, "Merging routes of node %d\n",TOS_NODE_ID);
        // call NeighborDiscovery.print();
        // call Routing.print();
        for(i = 0; i< listSize; i++){
            neighbor = call NeighborList.get(i);
            // dbg(ROUTING_CHANNEL, "Sending to directly connected neighbor: %d\n",neighbor);
            for(j = 1; j< TABLE_SIZE; j++){
                if(j == TOS_NODE_ID || neighbor == 0 || j == neighbor){
                    continue;
                }
                DVRinfo = call RoutingTable.get(j);
                DVRinfop = &DVRinfo;
                if(DVRinfop->cost != 255){
                    // dbg(ROUTING_CHANNEL, "Sending route Dest: %d Hop: %d Count: to node %d\n", DVRinfop->dest, DVRinfop->nextHop, DVRinfop->cost, neighbor);
                    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 10, PROTOCOL_LINKEDLIST, seqNum, (uint8_t *) DVRinfop, PACKET_MAX_PAYLOAD_SIZE);
                    seqNum++;
                    call RSender.send(sendPackage, neighbor);
                } 
            }
        }
    } 

    event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len){
        Route newPacket;
        if(len == sizeof(pack)){
            pack* myMsg=(pack*) payload;
            Route *newRoute = myMsg->payload;
            uint16_t k;
            Route temp;
            Route *nodeRoute;

            temp = call RoutingTable.get(newRoute->dest);
            nodeRoute = &temp;
            // if(newRoute->dest == nodeRoute->dest){
                if(newRoute->cost+1 < nodeRoute->cost){
                    // dbg(ROUTING_CHANNEL,"Old Route: Dest: %d Hop: %d Count: %d\n", nodeRoute->dest, nodeRoute->nextHop, nodeRoute->cost);
                    // dbg(ROUTING_CHANNEL,"Better Route: Dest: %d Hop: %d Count: %d + (1)\n", newRoute->dest, myMsg->src, newRoute->cost);
                    
                    // dbg(ROUTING_CHANNEL, "Before:\n");
                    // call Routing.print();
                    call RoutingTable.remove(k);
                    newPacket.nextHop = myMsg->src;
                    newPacket.cost = newRoute->cost + 1;
                    newPacket.dest = newRoute->dest;
                    call RoutingTable.insert(newRoute->dest, newPacket);
                    listSize = call NeighborList.size();
                    newRoute = &newPacket;

                    for(k = 0; k<listSize; k++){
                        if(k != neighbor){
                            makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 10, PROTOCOL_LINKEDLIST, seqNum, (uint8_t *) newRoute, PACKET_MAX_PAYLOAD_SIZE);
                            seqNum++;
                            call RSender.send(sendPackage, neighbor); 
                        }
                    }
                    return msg;
                    // dbg(ROUTING_CHANNEL, "After:\n");
                    // call Routing.print();
                }
                return msg;
            // }
        }
        return msg;
    }


    //RIP implementation (route advertising and merging routes)
    /*  
        Node tells immediate neighbors of dist to all other nodes
        Create and update routing table
        Determine next-hop and shortest paths
        Send packet using next-hops as directed by routing table
    */
    //Split Horizon implementation 
        //More info on project2notes.txt
        /*
        Example: A-B-C
        router A learns about C through B
        if A learned about C through B
            A will not send info about C to B
        */
    //Poison Reverse technique implementation
        //More info on project2notes.txt
        /*
        if route is unreachable
            route == inf
            broadcast to other nodes/routers
        */

    // Print Routing Table function (response to s.routeDMP())
    //The entire routing table should be printed when the command routingTableDump is called
    command void Routing.print(){

        dbg(ROUTING_CHANNEL, "Routing Table:\n");
        dbg(ROUTING_CHANNEL, "Dest\tHop\t\tCount\n");

        listSize = call RoutingTable.size();

        for(i = 1; i< TABLE_SIZE; i++){
            packet = call RoutingTable.get(i);
            if(i != TOS_NODE_ID){
                dbg(ROUTING_CHANNEL, "%d\t\t%d\t\t%d\n", packet.dest, packet.nextHop, packet.cost);
            }
        }
    }

    void makePack(pack* Packet, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length)
   {
      Packet->src = src;
      Packet->dest = dest;
      Packet->TTL = TTL;
      Packet->seq = seq;
      Packet->protocol = protocol;
      memcpy(Packet->payload, payload, length);
   }

}

