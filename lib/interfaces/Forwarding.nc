#include "../../includes/packet.h"

interface Forwarding{
   command void send(uint16_t dest, void *payload); 
}