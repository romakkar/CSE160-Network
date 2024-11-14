interface CommandHandler{
   // Events
   event void ping(uint16_t destination, void *payload);
   event void flood(int16_t destination, void *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer();
   event void setTestClient();
   event void setAppServer();
   event void setAppClient();
}