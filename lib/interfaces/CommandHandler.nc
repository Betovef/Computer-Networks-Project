interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint16_t port);
   event void setTestClient(uint16_t dest, uint16_t srcPort, uint16_t destPort, uint16_t transfer);
   event void ClientClosed(uint16_t addr, uint16_t dest, uint16_t srcPort, uint16_t destPort);
   event void hello(uint16_t clientport, char* username);
   event void Msg(char* msg);
   event void whisper(char *username, char* msg);
   event void listusr();
   event void setAppServer();
   event void setAppClient();
}
