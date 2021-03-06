/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   uses interface NeighborDiscovery; //Added
   uses interface SimpleSend as FSender;
   uses interface SimpleSend as RSender;
   uses interface Hashmap<Route> as RoutingTable;
   uses interface List<Route> as RouteTable; //not using this -delete later
   uses interface Routing;
}

implementation{
   pack sendPackage;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      
      dbg(GENERAL_CHANNEL, "Booted\n");
      call AMControl.start();
      call Routing.initializeTable();
      call NeighborDiscovery.start();
      call Routing.start();
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
         }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){ //runs only once

      dbg(GENERAL_CHANNEL, "PING EVENT \n"); //node x is trying to send to node y (TOS_NODE_ID to destination)
      if(call RoutingTable.contains(destination)){
         makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_LINKEDLIST, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
         // call Sender.send(sendPackage, AM_BROADCAST_ADDR); //destination needs to be AM_BROADCAST_ADDR (everywhere) Note- note sure if we still need this after implementing flooding
         dbg(GENERAL_CHANNEL, "Routing packet from %d to %d\n", TOS_NODE_ID, destination);
         call RSender.send(sendPackage, destination); //Starting flooding when protocol ping is called
      }
      else{
         makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
         // call Sender.send(sendPackage, AM_BROADCAST_ADDR); //destination needs to be AM_BROADCAST_ADDR (everywhere) Note- note sure if we still need this after implementing flooding
         dbg(GENERAL_CHANNEL, "There is no route, flooding packet from node %d to %d\n", TOS_NODE_ID, destination);
         call FSender.send(sendPackage, AM_BROADCAST_ADDR); //Starting flooding when protocol ping is called
      }
      
      
   }

   event void CommandHandler.printNeighbors(){
      call NeighborDiscovery.print();
   }

   event void CommandHandler.printRouteTable(){
      call Routing.print();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
