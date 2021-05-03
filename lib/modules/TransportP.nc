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
    uses interface Hashmap<char*> as usersTable;
    uses interface List<socket_t> as acceptList;
}
implementation{

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    socket_t getfd(uint8_t destPort);

    event void TransportTimer.fired()
    {
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
        socket_store_t clientSocket;
        uint16_t count = 0;
        uint16_t i = 0;
        uint16_t temp = 0;
        
        // dbg(TRANSPORT_CHANNEL, "Writing data from fd %d..\n", fd);

        if(call sockets.contains(fd))
        {
            clientSocket = call sockets.get(fd);
        }
        else{
            dbg(TRANSPORT_CHANNEL, "ERROR: socket list does not contain fd \n");
            return NULL;
        }

        // dbg(TRANSPORT_CHANNEL, "WHAT IS GOIGN ON %d\n", clientSocket.effectiveWindow);

        while(i < TCP_MAX_PAYLOAD_SIZE && i < clientSocket.effectiveWindow && i < bufflen){
            clientSocket.sendBuff[i] = buff[i];
            clientSocket.lastWritten = buff[i];
            dbg(TRANSPORT_CHANNEL, " Writing %c\n", clientSocket.sendBuff[i]); //change %d for project 3 and %s for project 4
            i++;
        }

        call sockets.insert(fd, clientSocket);

        return (i);

    }

    command error_t Transport.receive(pack* package)
    {
        tcp_segment* myMsg = (tcp_segment*)(package->payload); //unload payload
        socket_store_t serverSocket;
        socket_store_t clientSocket;
        socket_store_t tempSocket;
        socket_t fd;
        uint16_t i;

        tcp_segment* TCPpack; //new payload
        pack sendPackage; //new message packet

        //Three-way handshake
        if(myMsg->flags == SYN || myMsg->flags == SYN_ACK || myMsg->flags == ACK){
            if(myMsg->flags == SYN)
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
                    serverSocket.effectiveWindow = 20;
                    
                    call sockets.insert(fd, serverSocket);

                    //Setting up the response to client 
                    TCPpack = (tcp_segment*)(sendPackage.payload);
                    TCPpack->destPort = serverSocket.dest.port;
                    TCPpack->srcPort = serverSocket.src.port;

                    //(Flags = SYN ACK, Ack = x+1, SequenceNum = y)
                    TCPpack->seq = 1; // FIXME: need to give random number
                    TCPpack->ACK = myMsg->seq + 1;
                    TCPpack->flags = SYN_ACK;
                    TCPpack->advWindow = serverSocket.effectiveWindow; //avertise window to 5
                    
                    // Server received SYN message sending reply SYN+ACK 
                    dbg(TRANSPORT_CHANNEL, "Syn ACK Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
                    makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
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
                dbg(TRANSPORT_CHANNEL, "SYN ACK Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort); 
                fd = getfd(myMsg->destPort);
                clientSocket = call sockets.get(fd);

                //updating client socket state to ESTABLISHED
                clientSocket.state = ESTABLISHED;
                clientSocket.dest.port = myMsg->srcPort;
                clientSocket.dest.addr = package->src;
                // dbg(TRANSPORT_CHANNEL, "The effective window for the client end is %d \n", myMsg->advWindow);
                clientSocket.effectiveWindow = myMsg->advWindow;
                
                call sockets.insert(fd, clientSocket);

                //Setting up the response to server
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = clientSocket.dest.port;
                TCPpack->srcPort = clientSocket.src.port;
                    
                //(Flags = ACK, Ack = y + 1)
                TCPpack->ACK = myMsg->seq + 1;
                TCPpack->flags = ACK;

                // Client received SYN ACK message sending reply ACK 
                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "ACK Packet Sent to Node %d for Port %d \n", clientSocket.dest.addr, clientSocket.dest.port);
                call RSender.send(sendPackage, clientSocket.dest.addr); 
                call acceptList.pushback(package->src);
                // call clientTimer.startOneShot(15000);
            }
            else if(myMsg->flags == ACK)
            {
                dbg(TRANSPORT_CHANNEL, "ACK Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort); 
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);

                //updating server socket state to ESTABLISHED
                serverSocket.state = ESTABLISHED;
                serverSocket.dest.port = myMsg->srcPort;
                serverSocket.dest.addr = package->src;

                
                call sockets.insert(fd, serverSocket);

                dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been ESTABLISHED\n");
                call acceptList.pushback(package->src); 
            }
        }
        else if(myMsg->flags == DATA || myMsg->flags == DATA_ACK){
            //DATA TRANSPORT CONTROL
            if(myMsg->flags == DATA)
            {
                dbg(TRANSPORT_CHANNEL, "Data Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);
                if(myMsg->destPort == 41){
                    char* temp;
                    socket_t connectedSocket;
                    if(myMsg->data[0] == 'h'){ // if h appended to beggining it is a hello command
                        char* newUser = malloc(strlen(myMsg->data)-1);
                        for(i = 1; i< strlen(myMsg->data); i++){
                            newUser[i-1] = myMsg->data[i];
                        }
                        newUser[i] = '\0';
                        dbg(TRANSPORT_CHANNEL, "User %s src %d added to server \n", newUser, package->src);
                        call usersTable.insert(package->src, newUser);
                        
                        serverSocket.state = LISTEN; //listen for more connections
                        call sockets.insert(fd, serverSocket);

                    }
                    else if(myMsg->data[0] == 'm'){
                        TCPpack = (tcp_segment*)(sendPackage.payload);
                        TCPpack->srcPort = 41;
                        TCPpack->flags = PUSH;
                        // char* sendData = malloc(strlen(myMsg->data)-1);
                        for(i = 1; i< strlen(myMsg->data); i++){
                            TCPpack->data[i-1] = myMsg->data[i];
                        }
                        TCPpack->data[i] = '\0';
                        dbg(TRANSPORT_CHANNEL,"Broadcasting message to all connected clients\n");
                        for(i = 0; i < call acceptList.size(); i++){
                            connectedSocket = call acceptList.get(i);

                            dbg(TRANSPORT_CHANNEL, "Message Sent to Node %d\n", connectedSocket);
                            makePack(&sendPackage, TOS_NODE_ID, connectedSocket, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                            call RSender.send(sendPackage, connectedSocket);
                        }
                    }
                }
                else{
                    for(i = 0; i < serverSocket.effectiveWindow; i++){
                    serverSocket.rcvdBuff[i] = myMsg->data[i];
                    serverSocket.lastRcvd = myMsg->data[i];
                    // dbg(TRANSPORT_CHANNEL, "writing rcvdBuff %d \n ", serverSocket.rcvdBuff[i]);
                    }
                    dbg(TRANSPORT_CHANNEL, "The last received from server is %d \n", serverSocket.lastRcvd);
                    
                    call sockets.insert(fd, serverSocket);
                }

                

            }
            else if(myMsg->flags == DATA_ACK)
            {
                dbg(TRANSPORT_CHANNEL, "Data Ack Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);
                fd = getfd(myMsg->destPort);
                clientSocket = call sockets.get(fd);

                clientSocket.lastAck = myMsg->ACK;
                clientSocket.effectiveWindow = myMsg->advWindow;

                // dbg(TRANSPORT_CHANNEL, "Client lastSent is %d \n", clientSocket.lastSent);
                dbg(TRANSPORT_CHANNEL, "Client lastAck is %d\n", clientSocket.lastAck);

                
                call sockets.insert(fd, clientSocket);

            }
        }
        else if(myMsg->flags == PUSH){
            dbg(TRANSPORT_CHANNEL, "Node %d recieved message from server port 41\n", TOS_NODE_ID);
            dbg(TRANSPORT_CHANNEL, "Reanding message: %s\n", myMsg->data);

        }
        else{
            //TERMINATION CLOSING CONNECTION
            if(myMsg->flags == FIN)
            {
                fd = getfd(myMsg->destPort);
                tempSocket = call sockets.get(fd);

                dbg(TRANSPORT_CHANNEL, "FIN Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);

                //updating side to CLOSED
                tempSocket.state = CLOSE_WAIT;
                dbg(TRANSPORT_CHANNEL, "Socket in CLOSE_WAIT state\n");
                tempSocket.dest.port = myMsg->srcPort;
                tempSocket.dest.addr = package->src;

                call sockets.insert(fd, tempSocket);

            }
            else if(myMsg->flags == FIN_ACK) //only if both nodes close
            {
                dbg(TRANSPORT_CHANNEL, "FIN ACK Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);
                dbg(TRANSPORT_CHANNEL, "Socket in TIME_WAIT state\n");
                fd = getfd(myMsg->destPort);
                tempSocket = call sockets.get(fd);

                tempSocket.state = CLOSED;
                dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been CLOSED succesfully\n");
            } 
        }    
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        socket_store_t serverSocket;
        uint8_t i = 0;
        uint8_t temp = 0;

        serverSocket = call sockets.get(fd);

        // dbg(TRANSPORT_CHANNEL, "Last read is %d \n", serverSocket.lastRead);
        // dbg(TRANSPORT_CHANNEL, "Last recieved is %d \n", serverSocket.lastRcvd);
        if(serverSocket.lastRead != serverSocket.lastRcvd){
            // dbg(TRANSPORT_CHANNEL, "Reading socket %d \n", fd);
            for(i = 0; i < bufflen; i++)
            {
                temp = serverSocket.rcvdBuff[i];
                dbg(TRANSPORT_CHANNEL, "Reading data %d \n", temp);
                serverSocket.lastRead = temp;
            }

            call sockets.insert(fd, serverSocket);
            return (i+1);
        }
        else{
            return 0;
        }

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
        /*
        send out remaining data and a FIN packet
        Recieves remaining ACK - Become FIN_WAIT_2
        Once recieving a FIN from other node, become TIME_WAIT until CLOSED state
        If both nodes close:
            FIN is sent
            Once ACK+FIN is received, same process
        */

       

        if(call sockets.contains(fd)){
            socket_store_t tempSocket;
            uint16_t i;
            pack sendPackage;
            tcp_segment* TCPpack;

            tempSocket = call sockets.get(fd);

            if(tempSocket.state == ESTABLISHED){

                //Prepare packet
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = tempSocket.dest.port;
                TCPpack->srcPort = tempSocket.src.port;
                TCPpack->flags = FIN;

                //Update socket state
                tempSocket.state = FIN_WAIT_1;
                dbg(TRANSPORT_CHANNEL, "Starting Teardown\n");
                dbg(TRANSPORT_CHANNEL, "Socket in FIN_WAIT_1 state\n");
                dbg(TRANSPORT_CHANNEL, "Sending remaining data...\n");

                call sockets.insert(fd, tempSocket);

                dbg(TRANSPORT_CHANNEL, "FIN Packet Sent to Node %d for Port %d \n", tempSocket.dest.addr, tempSocket.dest.port);
                makePack(&sendPackage, TOS_NODE_ID, tempSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, tempSocket.dest.addr);

            }

            else if(tempSocket.state == CLOSE_WAIT){ //The reciever sends a FIN packet and becomes LAST_ACK
                //Prepare packet
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = tempSocket.dest.port;
                TCPpack->srcPort = tempSocket.src.port;
                TCPpack->flags = FIN;

                //Update socket state
                tempSocket.state = LAST_ACK;

                call sockets.insert(fd, tempSocket);

                dbg(TRANSPORT_CHANNEL, "Fin Packet Sent to Node %d for Port %d \n", tempSocket.dest.addr, tempSocket.dest.port);
                makePack(&sendPackage, TOS_NODE_ID, tempSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, tempSocket.dest.addr);
            }

        }
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

    command error_t Transport.sendBuffer(socket_t fd)
    {
        socket_store_t clientSocket;
        tcp_segment* TCPpack;
        pack sendPackage;
        uint16_t i = 0;

        clientSocket = call sockets.get(fd);
        TCPpack = (tcp_segment*)(sendPackage.payload);
        TCPpack->destPort = clientSocket.dest.port;
        TCPpack->srcPort = clientSocket.src.port;
        TCPpack->flags = DATA;

        // TCPpack = (tcp_segment*)(sendPackage.payload);
        if(call sockets.contains(fd)){

            // dbg(TRANSPORT_CHANNEL, "clientSocket.lastAck: %d clientSocket.lastSent %d \n", clientSocket.lastAck, clientSocket.lastSent);
            if(clientSocket.sendBuff[0]== 'h' || clientSocket.sendBuff[0]== 'm' || clientSocket.sendBuff[0]== 'w'){
                TCPpack->seq++;
                TCPpack->flags = DATA;

                for(i = 0; i < clientSocket.effectiveWindow; i++){
                    TCPpack->data[i] = clientSocket.sendBuff[i];
                    clientSocket.lastSent = TCPpack->data[i];
                    // dbg(TRANSPORT_CHANNEL, "TCP data payload is %d \n", TCPpack->data[i]);
                }
                
                call sockets.insert(fd, clientSocket);

                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, clientSocket.dest.addr);
                return SUCCESS;
            }
            else if(clientSocket.sendBuff[0] == 1){
                TCPpack->seq = 0;
                TCPpack->ACK = 1;
                TCPpack->flags = DATA;

                for(i = 0; i < clientSocket.effectiveWindow; i++){
                    TCPpack->data[i] = clientSocket.sendBuff[i];
                    clientSocket.lastSent = TCPpack->data[i];
                }
                dbg(TRANSPORT_CHANNEL, "Last integer sent is %d \n", clientSocket.lastSent);
                
                call sockets.insert(fd, clientSocket);

                dbg(TRANSPORT_CHANNEL, "DATA Packet Sent to Node %d for Port %d\n", clientSocket.dest.addr, clientSocket.dest.port);
                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, clientSocket.dest.addr);
                return SUCCESS;
            }
            else if(clientSocket.lastAck == clientSocket.lastSent){
                TCPpack->seq++;
                TCPpack->flags = DATA;

                for(i = 0; i < clientSocket.effectiveWindow; i++){
                    TCPpack->data[i] = clientSocket.sendBuff[i];
                    clientSocket.lastSent = TCPpack->data[i];
                    // dbg(TRANSPORT_CHANNEL, "TCP data payload is %d \n", TCPpack->data[i]);
                }
                
                call sockets.insert(fd, clientSocket);

                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, clientSocket.dest.addr);
                return SUCCESS;
            }
            else{
                dbg(TRANSPORT_CHANNEL, "Server has not sent ack\n");
                return FAIL;
            }

        }
        else{
            dbg(TRANSPORT_CHANNEL, "ERROR in sendBuffer: socket list does not contain fd \n");
            return FAIL;
        }
        // socket_store_t tempSocket = call sockets.get(fd);
    }

    command error_t Transport.sendAck(socket_t fd){

        socket_store_t serverSocket;
        tcp_segment* TCPpack;
        pack sendPackage;
        uint16_t i = 0;
        uint16_t temp;

        serverSocket = call sockets.get(fd);
        TCPpack = (tcp_segment*)(sendPackage.payload);
        TCPpack->destPort = serverSocket.dest.port;
        TCPpack->srcPort = serverSocket.src.port;

        if(serverSocket.state == ESTABLISHED){
            TCPpack->advWindow = 20;
            TCPpack->flags = DATA_ACK;
            TCPpack->ACK = serverSocket.lastRcvd;

            dbg(TRANSPORT_CHANNEL, "DATA ACK Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
        }
        else if(serverSocket.state == CLOSE_WAIT){
            TCPpack->flags = FIN_ACK;

            //remove associated fd connection to stop periodic reading
            for(i = 0; i < call acceptList.size(); i++){
                temp = call acceptList.popback();
                if(temp == serverSocket.dest.addr){
                    break;
                }
                else{
                    call acceptList.pushback(temp);
                }
            }
            dbg(TRANSPORT_CHANNEL, "FIN ACK Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
        }

        makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
        call RSender.send(sendPackage, serverSocket.dest.addr);
    }

    command error_t Transport.checkConnection(socket_t fd){
        uint8_t i = 0;
        socket_t temp = 0;
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