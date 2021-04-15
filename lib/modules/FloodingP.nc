#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/route.h"
#include "../../includes/tcp.h"


module FloodingP{
    provides interface SimpleSend as FSender;
    provides interface SimpleSend as RSender;
    uses interface NeighborDiscovery;
    uses interface Transport;

    //internal interfaces
    uses interface SimpleSend as InternalSender;
    uses interface Receive as InternalReceiver;
    uses interface List<pack> as PacketList;
    uses interface Hashmap<Route> as RoutingTable;
}
implementation{
    pack sendPackage;
    pack packets;
    tcp_segment* TCPpack;
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    bool checkPackets(pack *myMsg);

    uint16_t seqNum = 0;

    command error_t FSender.send(pack msg, uint16_t dest)
    {
        msg.seq++;
        call InternalSender.send(msg, AM_BROADCAST_ADDR);
    }

    command error_t RSender.send(pack msg, uint16_t dest)
    {
        Route route;
        route = call RoutingTable.get(dest);

        // dbg(ROUTING_CHANNEL, "Routing Packet -src: %d, dest: %d, seq: %d, next hop: %d, cost: %d\n", TOS_NODE_ID, dest, msg.seq, route.nextHop, route.cost); //uncomment for project 2
        msg.seq++;
        call InternalSender.send(msg, route.nextHop);
    }
    

    event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len)
    {
      
        if(len == sizeof(pack))
        {
            pack* myMsg=(pack*) payload;
            TCPpack = (tcp_segment*)(myMsg->payload);
            //  dbg(GENERAL_CHANNEL, "Node %d received signal from node %d\n",TOS_NODE_ID, myMsg->src);
            if(myMsg->TTL == 0 || checkPackets(myMsg) == TRUE)
            {   //Remember to adjust TTL to the number of nodes 
                // dbg(GENERAL_CHANNEL, "Node %d already received signal from node %d\n", TOS_NODE_ID, myMsg->src);
                // dbg(GENERAL_CHANNEL, "Current TTL %d \n", myMsg->TTL);
                return msg;
            }
            else if(TOS_NODE_ID == myMsg->dest && myMsg->protocol != PROTOCOL_TCP)
            {
                    call PacketList.pushback(*myMsg);
                    dbg(GENERAL_CHANNEL, "Pinging... \n"); 
                    dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
                    return msg;
            }
            else if(myMsg->protocol == PROTOCOL_TCP)
            {
                if(TOS_NODE_ID == myMsg->dest)
                {
                    // dbg(TRANSPORT_CHANNEL, "Node %d got packet of type %d\n",TOS_NODE_ID, TCPpack->flags);
                    call Transport.receive(myMsg);
                }
                else
                {
                    makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_TCP, seqNum+1, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                    call RSender.send(sendPackage, myMsg->dest);
                }
                return msg;
            }
            else if(myMsg->protocol == PROTOCOL_LINKEDLIST)
            {
                call PacketList.pushback(*myMsg);
                makePack(&sendPackage, TOS_NODE_ID, myMsg->dest, myMsg->TTL-1, PROTOCOL_LINKEDLIST, seqNum+1, (uint8_t *)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, myMsg->dest);
                return msg;
            }
            else
            {
                call PacketList.pushback(*myMsg);
                makePack(&sendPackage, TOS_NODE_ID, myMsg->dest, myMsg->TTL-1, PROTOCOL_PING, seqNum, (uint8_t *)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                // dbg(GENERAL_CHANNEL, "Package destiny: %d\n", myMsg->dest);
                call InternalSender.send(sendPackage, AM_BROADCAST_ADDR);
                return msg;
            }
        }
        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
   }   
    
     bool checkPackets(pack *myMsg)
     {
        uint16_t size = 0;
        uint16_t i = 0;
        bool inList;
        size = call PacketList.size();
        for(i = 0; i< size; i++)
        {
            packets = call PacketList.get(i);
            if(myMsg->src == packets.src)
            {
                return TRUE;
            }
        }
        return FALSE;
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
