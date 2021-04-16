#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/protocol.h"
#include "../../includes/sendInfo.h"
#include "../../includes/route.h"
#include "../../includes/tcp.h"

module TransportP{
    provides interface Transport;

    uses interface Timer<TMilli> as TransportTimer;
    // uses interface Timer<TMilli> as clientTimer;
    uses interface SimpleSend as RSender;
    uses interface Hashmap<Route> as RoutingTable;
    uses interface Hashmap<socket_store_t> as sockets;
    uses interface List<socket_t> as acceptList;
}
implementation{

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    socket_t getfd(uint8_t destPort);

    event void TransportTimer.fired()
    {
        //need to work on this
    }

    // event void clientTimer.fired()
    // {
    //     dbg(TRANSPORT_CHANNEL, "NEED TO WRITE DATA!!!\n");
        
    // }

    command socket_t Transport.socket()
    {
        socket_t fd;
        socket_store_t tempSocket;
        uint16_t i = 0;
        if(call sockets.size() < MAX_NUM_OF_SOCKETS) //check if sockets available
        {
            fd = call sockets.size()+1; //fd related to the size of the sockets storage
            
            // This is the sender portion
            tempSocket.fd = fd;
            tempSocket.effectiveWindow = 0;
            tempSocket.lastWritten = 0;
            tempSocket.lastAck = 0;
            tempSocket.lastSent = 0;

            for(i = 0; i < SOCKET_BUFFER_SIZE; i++){
                tempSocket.sendBuff[i] = 0;
                tempSocket.rcvdBuff[i] = 0;
            }

            // This is the receiver portion
            tempSocket.lastRead = 0;
            tempSocket.lastRcvd = 0;
            tempSocket.nextExpected = 0;
            call sockets.insert(fd, tempSocket);

            return fd;
        }
        else
        {
            dbg(TRANSPORT_CHANNEL, "Unable to allocate socket \n");
            return NULL;
        }
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
    {
        socket_store_t tempSocket; 
        if(call sockets.contains(fd)) //check if socket exists in sockets available
        {
            tempSocket = call sockets.get(fd);

            tempSocket.src.port = addr->port;
            tempSocket.src.addr = addr->addr;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);

            return SUCCESS;
        }
        else
        {
            dbg(TRANSPORT_CHANNEL, "ERROR: Binding failed socket %d not found\n", fd);
            return FAIL;
        }

    }

    command socket_t Transport.accept(socket_t fd)
    {
        uint8_t i  = 0;
        socket_t tempFd;
        for(i = 0; i < call acceptList.size(); i++)
        {
            tempFd = call acceptList.get(i); //if socket is already accepted return null
            if(tempFd == fd){
                return fd;
            }
        }
        return NULL;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        pack sendPackage;
        socket_store_t clientSocket;
        //uint16_t dataNotWritten;
        uint8_t i = 0;
        uint16_t temp = 0;

        if(call sockets.contains(fd))
        {
            clientSocket = call sockets.get(fd);
        }
        else{
            dbg(TRANSPORT_CHANNEL, "ERROR: socket list does not contain fd \n");
            return NULL;
        }

        dbg(TRANSPORT_CHANNEL, "Writing data...\n");

        // for(i = 0; i < bufflen; i++) 
        // {
        //     temp = buff[i];
        //     dbg(TRANSPORT_CHANNEL, "Writing %d in buffer\n", temp);
        // }

        for(i = 0; i< clientSocket.effectiveWindow; i++)
        {
            clientSocket.sendBuff[i] = buff[i];
            clientSocket.lastWritten = buff[i];
        }

        call sockets.remove(fd);
        call sockets.insert(fd, clientSocket);

        temp = clientSocket.effectiveWindow;

        return temp;


        // if(clientSocket.lastAck <= clientSocket.lastWritten)
        // {
        //     dataNotWritten = SOCKET_BUFFER_SIZE - (clientSocket.lastAck + clientSocket.lastWritten);
        // }
        // else
        // {
        //    dbg(TRANSPORT_CHANNEL, "data ack is ahead of data written???\n");
        // }
        // if(dataNotWritten <= bufflen)
        // {
        //     dbg(TRANSPORT_CHANNEL, "Need more space to write\n");
        // }
        // else
        // {
        // }

    }

    command error_t Transport.receive(pack* package)
    {
        tcp_segment* myMsg = (tcp_segment*)(package->payload); //unload payload
        socket_store_t serverSocket;
        socket_store_t clientSocket;
        socket_store_t tempSocket;
        socket_t fd;
        uint16_t i;
        uint8_t bufflen = TCP_MAX_PAYLOAD_SIZE;
        uint8_t msgBuff[TCP_MAX_PAYLOAD_SIZE];


        tcp_segment* TCPpack; //new payload
        pack sendPackage; //new message packet

        //Three-way handshake
        if(myMsg->flags == SYN)
        {
            fd = getfd(myMsg->destPort);
            serverSocket = call sockets.get(fd);
            dbg(TRANSPORT_CHANNEL, "SYN Packet Arrived from Node %d for Port %d\n", package->src, myMsg->srcPort);
            if(serverSocket.state == LISTEN)
            {
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);
                dbg(TRANSPORT_CHANNEL, "SYN Packet Arrived from Node %d for Port %d\n", package->src, myMsg->srcPort);
                if(serverSocket.state == LISTEN)
                {
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

                    //(Flags = SYN ACK, Ack = x+1, SequenceNum = y)
                    TCPpack->seq = 1; // FIXME: need to give random number
                    TCPpack->ACK = myMsg->seq + 1;
                    TCPpack->flags = SYN_ACK;
                    TCPpack->advWindow = SOCKET_BUFFER_SIZE;
                    
                    // Server received SYN message sending reply SYN+ACK 
                    makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                    dbg(TRANSPORT_CHANNEL, "Syn Ack Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
                    call RSender.send(sendPackage, serverSocket.dest.addr); 
                }
                else
                {
                    dbg(TRANSPORT_CHANNEL, "SERVER NOT LISTENING\n");
                    //may be add retransmission ??
                }
            }
            else if(myMsg->flags == SYN_ACK)
            {
                dbg(TRANSPORT_CHANNEL, "SYN Ack Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort); 
                fd = getfd(myMsg->destPort);
                clientSocket = call sockets.get(fd);

                //updating client socket state to ESTABLISHED
                clientSocket.state = ESTABLISHED;
                clientSocket.dest.port = myMsg->srcPort;
                clientSocket.dest.addr = package->src;

                clientSocket.effectiveWindow = myMsg->advWindow;
                call sockets.remove(fd);
                call sockets.insert(fd, clientSocket);

                //Setting up the response to server
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = clientSocket.dest.port;
                TCPpack->srcPort = clientSocket.src.port;
                    
                //(Flags = ACK, Ack = y + 1)
                TCPpack->ACK = myMsg->seq + 1;
                TCPpack->flags = ACK;
                TCPpack->advWindow = SOCKET_BUFFER_SIZE;

                // Client received SYN ACK message sending reply ACK 
                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "Ack Packet Sent to Node %d for Port %d \n", clientSocket.dest.addr, clientSocket.dest.port);
                call RSender.send(sendPackage, clientSocket.dest.addr); 
                // call clientTimer.startOneShot(15000);
                // call Transport.accept(fd);
                // dbg(TRANSPORT_CHANNEL, "Client ready to write DATA starting STOP AND WAIT PROTOCOL\n");
                // call Transport.write(fd, uint8_t *buff, uint16_t bufflen)
            }
            else if(myMsg->flags == ACK)
            {
                dbg(TRANSPORT_CHANNEL, "Ack Packet Arrved from Node %d for Port %d \n", package->dest, myMsg->destPort); 
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);

                //updating server socket state to ESTABLISHED
                serverSocket.state = ESTABLISHED;
                serverSocket.dest.port = myMsg->srcPort;
                serverSocket.dest.addr = package->src;
                serverSocket.effectiveWindow = myMsg->advWindow;
                call sockets.remove(fd);
                call sockets.insert(fd, serverSocket);
                dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been ESTABLISHED\n");
                call acceptList.pushback(fd);
                // dbg(TRANSPORT_CHANNEL, "Server ready to read DATA\n");
                
            }
        }
        else if(myMsg->flags == DATA || myMsg->flags == DATA_ACK){
            //DATA TRANSPORT CONTROL
            if(myMsg->flags == DATA)
            {
                dbg(TRANSPORT_CHANNEL, "Server received data packet \n");
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);

                
                for(i = 0; i < 5; i++)
                {
                    serverSocket.rcvdBuff[i] = myMsg->data[i];
                }

                call sockets.remove(fd);
                call sockets.insert(fd, serverSocket);

            }
            else if(myMsg->flags == DATA_ACK)
            {

            }
        }
        else{
                //TERMINATION CLOSING CONNECTION
            if(myMsg->flags == FIN)
            {
                fd = getfd(myMsg->destPort);
                tempSocket = call sockets.get(fd);

                dbg(TRANSPORT_CHANNEL, "FIN Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);

                //updating side to CLOSED
                tempSocket.state = CLOSED;
                tempSocket.dest.port = myMsg->srcPort;
                tempSocket.dest.addr = package->src;

                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = tempSocket.dest.port;
                TCPpack->srcPort = tempSocket.src.port;
                TCPpack->seq = 1;
                TCPpack->ACK = myMsg->seq + 1;
                TCPpack->flags = FIN_ACK;
                call sockets.remove(fd);
                call sockets.insert(fd, tempSocket);

                makePack(&sendPackage, TOS_NODE_ID, tempSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "FIN ACK Packet Sent to Node %d for Port %d \n", tempSocket.dest.addr, tempSocket.dest.port);

            }
            else if(myMsg->flags == FIN_ACK)
            {
                dbg(TRANSPORT_CHANNEL, "FIN ACK Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);

                fd = getfd(myMsg->destPort);
                tempSocket = call sockets.get(fd);

                tempSocket.state = CLOSED;
                dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been CLOSED\n");
            } 
        }
        
        

        
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        // pack sendPackage;
        socket_store_t serverSocket;
        // uint16_t dataNotWritten;
        uint8_t i = 0;
        uint8_t temp = 0;

        dbg(TRANSPORT_CHANNEL, "Reading socket %d \n", fd);

        serverSocket = call sockets.get(fd);
        for(i = 0; i <5; i++)
        {
            temp = serverSocket.rcvdBuff[i];
            dbg(TRANSPORT_CHANNEL, "Read %d in server buffer\n", temp);
        }

        return 5;

        // for(i = 0; )
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
    {
        pack sendPackage; //message
        tcp_segment* TCPpack; //payload

        socket_store_t clientSocket = call sockets.get(fd);
        TCPpack = (tcp_segment*)(sendPackage.payload);
        clientSocket.dest.port = addr->port;
        clientSocket.dest.addr = addr->addr;
        TCPpack->destPort = clientSocket.dest.port;
        TCPpack->srcPort = clientSocket.src.port;

        //(Flags = SYN, SequenceNum = x) NOTE: sequence number should be random
        TCPpack->ACK = 0;
        TCPpack->seq = 1;
        TCPpack->flags = SYN;
        TCPpack->advWindow = SOCKET_BUFFER_SIZE;

        if(call RoutingTable.contains(addr->addr)) //check if there is a route to dest (server)
        { 
            clientSocket.state = SYN_SENT; //update state
            dbg(TRANSPORT_CHANNEL, "Starting Three-Way Handshake\n");
            dbg(TRANSPORT_CHANNEL, "SYN Packet Sent to Node %d for Port %d \n", clientSocket.dest.addr, clientSocket.dest.port);
            makePack(&sendPackage, TOS_NODE_ID, addr->addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
            call RSender.send(sendPackage, addr->addr);

            return SUCCESS;
        }
        else
        {
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

        if(call sockets.contains(fd)) //check if socket exists
        { 
            tempSocket = call sockets.get(fd);
            tempSocket.state = LISTEN;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);
            
            return SUCCESS;
        }
        else
        {
            return FAIL;
        }
    }

    socket_t getfd(uint8_t srcPort)
    {
        socket_store_t tempSocket;
        uint8_t i;

        for(i = 0; i < call sockets.size(); i++)
        {
            tempSocket = call sockets.get(i);
            if(tempSocket.src.port == srcPort)
            {
                return i;
            }
        }
    }

    command error_t Transport.sendBuffer(uint8_t fd)
    {
        socket_store_t tempSocket;
        tcp_segment* TCPpack;
        pack sendPackage;
        uint8_t i = 0;

        // TCPpack = (tcp_segment*)(sendPackage.payload);
        if(call sockets.contains(fd)){

            tempSocket = call sockets.get(fd);
            TCPpack = (tcp_segment*)(sendPackage.payload);
            TCPpack->destPort = tempSocket.dest.port;
            TCPpack->srcPort = tempSocket.src.port;

            for(i = 0; i < 5; i++)
            {
                TCPpack->data[i] = tempSocket.sendBuff[i];
                // dbg(TRANSPORT_CHANNEL, "Transfer data %d\n", TCPpack->data[i]);
            }
            // TCPpack->data = tempSocket.sendBuff;
            
            TCPpack->ACK = 0;
            TCPpack->seq = 1;
            TCPpack->flags = DATA;

            makePack(&sendPackage, TOS_NODE_ID, 1, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
            call RSender.send(sendPackage, tempSocket.dest.addr);
        }
        else{
            dbg(TRANSPORT_CHANNEL, "ERROR in sendBuffer: socket list does not contain fd \n");
            return FAIL;
        }
        // socket_store_t tempSocket = call sockets.get(fd);
    }

    command error_t Transport.checkConnection(uint8_t fd){
        uint8_t i = 0;
        uint8_t temp = 0;
        for(i = 0; i < call acceptList.size(); i++){
            temp = call acceptList.get(i);
            if(temp == fd){
                return SUCCESS;
            }
        }
        return FAIL;
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