//header from Node (using the same implementation ping to ping)
#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#define NEIGHBORHOOD_SIZE 4; //how many nodes do we need?
#define TIMEOUT 10; //what is a good timeout?

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as PeriodicTimer;
    uses interface SimpleSend as NSender;
    uses interface Receive as NReceiver;
    uses interface Random as RandomTimer;
    uses interface Hashmap<pack> as NHashmap;

}
implementation{

    pack sendPackage;
    uint16_t timer2;
    uint16_t timer1;
    uint32_t seqCounter = 0;

    // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void updateNeighbors(); //Updates active and inactive neighbors
   void discoverNeighbors(); 

   command void NeighborDiscovery.start(){ //command called when booting
    timer1 = (1000 + (uint16_t)((call RandomTimer.rand16())%1000)); 
    timer2 = (1000 + (uint16_t)((call RandomTimer.rand16())%2000));
    dbg(NEIGHBOR_CHANNEL, "Timer: %d to %d\n", timer1, timer2); //created a peridoic timer from period t1 to t2
    call PeriodicTimer.startPeriodicAt(timer1, timer2); //the first timer will fire first
   }     
                                                
   command void NeighborDiscovery.print(){ //TOS_NODE_ID is the node fired
      //discover neighbor
      //Print them out
      //increment ages if youre going to do that
      // uint16_t i = 0;

      // for(i=0; i <NList[i].size(); i++){
      //    dbg(NEIGHBOR_CHANNEL, "Neighbor discovery module works!\n");
      // }
      // return;
   }

   event void PeriodicTimer.fired() //fired means that TOS_NODE_ID is sending signal in all directions, the smaller timer fires first
   {
      dbg(NEIGHBOR_CHANNEL, "Node %d fires!\n", TOS_NODE_ID);
      discoverNeighbors();

   }

   void discoverNeighbors(){
         dbg(NEIGHBOR_CHANNEL, "Searching for neighbors...\n");
         makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 4, PROTOCOL_PING, 0, "Are you my neighbor?", PACKET_MAX_PAYLOAD_SIZE);
         call NSender.send(sendPackage, AM_BROADCAST_ADDR); //sending package to everyone near node(the one that fired)
                                                            //we use protocol ping reply for neighbor discovery
      }
   
   void updateNList(uint16_t src){
      // uint16_t i;
      // pack newNeighbor;
      // for(i = 0; i<NList.size(); i++){
      //    newNeighbor = call NList.get(i);
      //    if(newNeighbor.TTL = TIMEOUT);
      //       return;
      //    newNeighbor.src = src;
      //    newNeighbor.TTL = TIMEOUT;
      //    seqCounter++;
      // }
   }

   // pack* myMsg; //why only works if outside of the function?

   event message_t* NReceiver.receive(message_t* msg, void* payload, uint8_t len){ 
      pack* myMsg=(pack*) payload;
      dbg(NEIGHBOR_CHANNEL, "Node %d is neighbor with node %d !\n", myMsg->src, TOS_NODE_ID);
      // dbg(NEIGHBOR_CHANNEL, "Packet Received: %s\n", payload);
      // myMsg=(pack*) payload;
      if(myMsg->dest == TOS_NODE_ID){ //if message destiny reaches its final destination
      //add node to the list myMSG->src list.pushback()
      //if protocol is pint reply neighbor discovery//else if protocol is ping glooding
         myMsg->dest = myMsg->src;
         myMsg->src = TOS_NODE_ID;
         myMsg->protocol = PROTOCOL_PING;
         call NSender.send(*myMsg, myMsg->dest);
      }
      // else if(myMsg->dest == TOS_NODE_ID){
      //    //refresh timeout
      //    uint16_t i;
      //    pack isNeighborInList;
      //    for(i=0; i< call NList.size(); i++){
      //       isNeighborInList = call NList.get(i);
      //       if(isNeighborInList.src == myMsg->src){
      //          isNeighborInList.TTL = TIMEOUT;
      //       }
      //    }
      //    isNeighborInList = call NList.get(seqCounter);
      //    isNeighborInList.src = myMsg->src;
      //    seqCounter++;

      // }
      dbg(NEIGHBOR_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
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