#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/protocol.h"
#include "../../includes/sendInfo.h"
#include "../../includes/route.h"
#include "../../includes/tcp.h"

module TransportP{
    provides interface Transport;

    uses interface SimpleSend as RSender;
    uses interface Hashmap<Route> as RoutingTable;
    uses interface Hashmap<socket_store_t> as sockets;
}
implementation{
    pack sendPackage;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    socket_t getfd(uint8_t destPort);


    command socket_t Transport.socket()
    {
        socket_t fd;
        socket_store_t tempSocket;
        if(call sockets.size() < MAX_NUM_OF_SOCKETS)
        {
            fd = call sockets.size()+1;
            tempSocket.fd = fd;
            call sockets.insert(fd, tempSocket);
        }
        else
        {
            dbg(TRANSPORT_CHANNEL, "Unable to allocate socket \n");
            return NULL;
        }
        return fd;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
    {
        socket_store_t tempSocket; 
        socket_addr_t tempAddress; 
        if(call sockets.contains(fd)){
            tempSocket = call sockets.get(fd);
            tempAddress.port = addr->port;
            tempAddress.addr = addr->addr;
            tempSocket.dest = tempAddress;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);

            return SUCCESS;
        }
        else{
            return FAIL;
        }

    }

    command socket_t Transport.accept(socket_t fd)
    {

    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {

    }

    command error_t Transport.receive(pack* package)
    {
        tcp_segment* myMsg = (tcp_segment*)(package->payload);
        socket_store_t serverSocket;
        socket_store_t clientSocket;
        socket_t fd;

        tcp_segment* TCPpack;
        pack sendPackage;
        //Tree-way handshake
        if(myMsg->flags == SYN){
            fd = getfd(myMsg->destPort);
            serverSocket = call sockets.get(fd);
            dbg(TRANSPORT_CHANNEL, "SYN Packet Arrived from Node %d for Port %d\n", package->dest, myMsg->destPort);
            if(serverSocket.state == LISTEN){

                //updating server socket state to SYN_RCVD
                serverSocket.state = SYN_RCVD;
                serverSocket.dest.port = myMsg->srcPort;
                serverSocket.dest.addr = package->src;
                call sockets.remove(fd);
                call sockets.insert(fd, serverSocket);

                //Setting up the response to client 
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = serverSocket.dest.port;
                TCPpack->srcPort = serverSocket.src.port;
                TCPpack->seq = 1; // FIXME: need to fix sequences
                TCPpack->ACK = TCPpack->seq + 1;
                TCPpack->flags = SYN_ACK;
                
                // Server received SYN message sending reply SYN+ACK 
                makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "Syn Ack Packet Sent to Node %d for Port %d \n", serverSocket.dest.addr, serverSocket.dest.port);
                call RSender.send(sendPackage, serverSocket.dest.addr); 
            }
            else{
                dbg(TRANSPORT_CHANNEL, "SERVER NOT LISTENING\n");
            }
        }
        else if(myMsg->flags == SYN_ACK){
                dbg(TRANSPORT_CHANNEL, "SYN Ack Packet Arrved from Node %d for Port %d \n", package->dest, myMsg->destPort); //FIXME: need to fix ports, they are being updated incorrectly
                fd = getfd(myMsg->destPort);
                clientSocket = call sockets.get(fd);

                //updating client socket state to ESTABLISHED
                clientSocket.state = ESTABLISHED;
                clientSocket.dest.port = myMsg->srcPort;
                clientSocket.dest.addr = package->src;
                call sockets.remove(fd);
                call sockets.insert(fd, clientSocket);

                //Setting up the response to server
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = clientSocket.dest.port;
                TCPpack->srcPort = clientSocket.src.port;
                TCPpack->seq = 1; // FIXME: need to fix sequences
                TCPpack->ACK = TCPpack->seq + 1;
                TCPpack->flags = ACK;

                // Clent received SYN ACK message sending reply ACK 
                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "Ack Packet Sent to Node %d for Port %d \n", clientSocket.dest.addr, clientSocket.dest.port);
                call RSender.send(sendPackage, clientSocket.dest.addr); 
            }
        else if(myMsg->flags == ACK){
            dbg(TRANSPORT_CHANNEL, "Ack Packet Arrved from Node %d for Port %d \n", package->dest, myMsg->destPort); //FIXME: need to fix ports, they are being updated incorrectly
            fd = getfd(myMsg->destPort);
            serverSocket = call sockets.get(fd);

            //updating server socket state to ESTABLISHED
            serverSocket.state = ESTABLISHED;
            serverSocket.dest.port = myMsg->srcPort;
            serverSocket.dest.addr = package->src;
            call sockets.remove(fd);
            call sockets.insert(fd, serverSocket);
             dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been ESTABLISHED\n");
        }

    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
    {
        tcp_segment* TCPpack;
        socket_store_t mySocket = call sockets.get(fd);

        TCPpack = (tcp_segment*)(sendPackage.payload);
        TCPpack->destPort = mySocket.dest.port;
        TCPpack->srcPort = mySocket.src.port;
        TCPpack->ACK = 0;
        TCPpack->seq = 1;
        TCPpack->flags = SYN;

        if(call RoutingTable.contains(addr->addr)){
            mySocket.state = SYN_SENT;
            dbg(TRANSPORT_CHANNEL, "Starting Three-Way Handshake\n");
            dbg(TRANSPORT_CHANNEL, "CLIENT: Sending segment of type SYN\n", TCPpack->seq);
            makePack(&sendPackage, TOS_NODE_ID, addr->addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
            call RSender.send(sendPackage, addr->addr); 
            
            return SUCCESS;
        }
        else{
            return FAIL;
        }
    }

    command error_t Transport.close(socket_t fd)
    {

    }

    command error_t Transport.release(socket_t fd)
    {

    }

    command error_t Transport.listen(socket_t fd)
    {
        socket_store_t tempSocket;
        enum socket_state tempState;

        if(call sockets.contains(fd)){
            tempSocket = call sockets.get(fd);
            tempState = LISTEN;
            tempSocket.state = tempState;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);
            
            return SUCCESS;
        }
        else{
            return FAIL;
        }
    }

    socket_t getfd(uint8_t destPort){
        socket_store_t tempSocket;
        uint8_t i;

        for(i = 0; i<call sockets.size(); i++){
            tempSocket = call sockets.get(i);
            if(tempSocket.dest.port == destPort){
                return i;
            }
        }
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}